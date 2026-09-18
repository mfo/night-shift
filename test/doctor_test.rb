# frozen_string_literal: true

require_relative 'test_helper'
require 'minitest/mock'
require 'tmpdir'
require 'fileutils'
require 'stringio'

#
# The doctor is the only part of nightshift allowed to delete things. What
# matters is not that it reclaims disk, it is that it refuses to touch anything
# holding work that exists nowhere else.
#
class DoctorTest < Minitest::Test
  DOC = Nightshift::Monitoring::Doctor
  WT  = Nightshift::Integrations::Worktree
  GIT = Nightshift::Integrations::Git
  ACT = Nightshift::CleanupAction

  def item(kind:, label:, action:, **rest)
    Nightshift::Core::WorkItem.new(
      kind: kind, label: label, cleanup: action, repo: '/repo', **rest
    )
  end

  NO_BRANCH = Object.new

  def worktree_item(label, branch: NO_BRANCH, **rest)
    resolved = branch.equal?(NO_BRANCH) ? label : branch
    item(kind: Nightshift::WorkItemKind::Worktree, label: label,
         action: ACT::CloseWorktree, branch: resolved,
         path: "/dev/#{label}", **rest)
  end

  def report(items)
    Nightshift::Core::Inventory::Report.new(repo: '/repo', items: items, deep: true)
  end

  def io = @io ||= StringIO.new

  # --- refusals ---------------------------------------------------------------

  def test_a_worktree_with_uncommitted_work_is_never_closed
    rep = report([worktree_item('dirty', dirty: true, size_bytes: 999)])
    closed = []

    WT.stub(:cleanup, ->(branch, **_) { closed << branch }) do
      DOC.apply(rep, io: io)
    end

    assert_empty closed
    assert_equal 1, rep.blocked.size
  end

  def test_a_worktree_with_unpushed_commits_is_never_closed
    rep = report([worktree_item('ahead', unpushed: true)])
    closed = []

    WT.stub(:cleanup, ->(branch, **_) { closed << branch }) do
      DOC.apply(rep, io: io)
    end

    assert_empty closed
    assert_includes rep.blocked.first.blockers, 'commits non poussés'
  end

  def test_an_unverifiable_directory_is_never_removed
    ghost = item(kind: Nightshift::WorkItemKind::GhostDir, label: 'husk',
                 action: ACT::RemoveDir, path: '/dev/husk', unknown_state: true)
    rep = report([ghost])

    removed = []
    FileUtils.stub(:rm_rf, ->(path) { removed << path }) do
      DOC.apply(rep, io: io)
    end

    assert_empty removed
  end

  def test_blocked_items_never_count_as_reclaimable
    rep = report([worktree_item('dirty', dirty: true, size_bytes: 10_000),
                  worktree_item('clean', size_bytes: 40)])

    assert_equal 40, rep.reclaimable_bytes
  end

  # --- what it does do --------------------------------------------------------

  def test_clean_worktrees_are_closed
    rep = report([worktree_item('done-a'), worktree_item('done-b')])
    closed = []

    WT.stub(:cleanup, ->(branch, **_) { closed << branch }) do
      DOC.apply(rep, io: io)
    end

    assert_equal %w[done-a done-b], closed
  end

  def test_a_detached_worktree_is_reported_not_guessed_at
    rep = report([worktree_item('detached', branch: nil)])
    closed = []

    tally = WT.stub(:cleanup, ->(branch, **_) { closed << branch }) do
      DOC.apply(rep, io: io)
    end

    assert_empty closed
    assert_equal 0, tally['worktrees']
    assert_match(/à fermer à la main/, io.string)
  end

  def test_orphan_databases_are_dropped_in_one_call
    rep = report([
      item(kind: Nightshift::WorkItemKind::OrphanDb, label: 'tps_test_a', action: ACT::DropDatabase),
      item(kind: Nightshift::WorkItemKind::OrphanDb, label: 'tps_test_b', action: ACT::DropDatabase)
    ])
    dropped = nil

    WT.stub(:drop_databases, ->(names) { dropped = names }) do
      DOC.apply(rep, io: io)
    end

    assert_equal %w[tps_test_a tps_test_b], dropped
  end

  def test_stale_branches_go_through_branch_dash_d
    rep = report([
      item(kind: Nightshift::WorkItemKind::StaleBranch, label: 'old', action: ACT::DeleteBranch, branch: 'old'),
      item(kind: Nightshift::WorkItemKind::StaleBranch, label: 'nope', action: ACT::DeleteBranch, branch: 'nope')
    ])

    # git refusing an unmerged branch is the guard rail, not a failure.
    GIT.stub(:delete_branch, ->(_repo, branch) { branch == 'old' }) do
      tally = DOC.apply(rep, io: io)
      assert_equal 1, tally['branches']
    end

    assert_match(/1 refusée/, io.string)
  end

  def test_prune_runs_once_for_all_dead_admin_entries
    rep = report([
      item(kind: Nightshift::WorkItemKind::Worktree, label: 'a', action: ACT::PruneAdmin, missing_dir: true),
      item(kind: Nightshift::WorkItemKind::Worktree, label: 'b', action: ACT::PruneAdmin, missing_dir: true)
    ])
    calls = 0

    GIT.stub(:prune_worktrees, ->(_repo) { calls += 1 }) do
      DOC.apply(rep, io: io)
    end

    assert_equal 1, calls
  end

  def test_husk_directories_are_removed
    Dir.mktmpdir do |root|
      husk = File.join(root, 'auto-i18n-hardcoded-batch-11d93b2e')
      FileUtils.mkdir_p(File.join(husk, 'tmp'))

      rep = report([item(kind: Nightshift::WorkItemKind::GhostDir, label: 'husk',
                         action: ACT::RemoveDir, path: husk)])
      DOC.apply(rep, io: io)

      refute Dir.exist?(husk)
    end
  end

  # --- scoping and confirmation ----------------------------------------------

  def test_only_restricts_to_one_category
    rep = report([worktree_item('wt'),
                  item(kind: Nightshift::WorkItemKind::OrphanDb, label: 'tps_test_a',
                       action: ACT::DropDatabase)])
    closed = []
    dropped = []

    WT.stub(:cleanup, ->(branch, **_) { closed << branch }) do
      WT.stub(:drop_databases, ->(names) { dropped.concat(names) }) do
        DOC.apply(rep, only: 'dbs', io: io)
      end
    end

    assert_empty closed
    assert_equal %w[tps_test_a], dropped
  end

  def test_a_refused_confirmation_stops_the_category
    rep = report([worktree_item('wt')])
    closed = []

    WT.stub(:cleanup, ->(branch, **_) { closed << branch }) do
      DOC.apply(rep, io: io, confirm: ->(_category, _items) { false })
    end

    assert_empty closed
  end

  def test_confirmation_receives_the_items_it_is_about_to_destroy
    rep = report([worktree_item('wt')])
    seen = nil

    WT.stub(:cleanup, ->(_branch, **_) {}) do
      DOC.apply(rep, io: io, confirm: lambda { |category, items|
        seen = [category.key, items.map(&:label)]
        true
      })
    end

    assert_equal ['worktrees', %w[wt]], seen
  end

  def test_unknown_category_resolves_to_nothing
    assert_empty DOC.categories('nope')
  end

  # --- rendering --------------------------------------------------------------

  def test_render_separates_what_it_would_do_from_what_it_refuses
    rep = report([worktree_item('clean', size_bytes: 2048),
                  worktree_item('dirty', dirty: true, size_bytes: 4096)])
    DOC.render(rep, io: io)

    out = io.string
    assert_match(/WORKTREES DONT LA PR EST CLOSE \(1\)/, out)
    assert_match(/NON TOUCHÉS \(1\)/, out)
    assert_match(/modifs non commitées/, out)
    assert_match(/2\.0 Ko récupérables/, out)
  end

  def test_render_says_so_when_there_is_nothing_to_do
    DOC.render(report([]), io: io)

    assert_match(/rien à nettoyer/, io.string)
  end
end
