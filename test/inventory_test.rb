# frozen_string_literal: true

require_relative 'test_helper'
require 'minitest/mock'
require 'tmpdir'
require 'fileutils'

#
# The inventory is the one place that is supposed to see everything. These tests
# pin the two things it got wrong before it existed: a PR with no worktree being
# invisible, and a worktree whose branch was renamed mid-run escaping every
# `auto/` filter.
#
class WorktreeEntryTest < Minitest::Test
  E = Nightshift::Core::WorktreeEntry

  PORCELAIN = <<~OUT
    worktree /Users/mfo/dev/demarches-simplifiees.fr
    HEAD e3257af1a9086b61f2e92a04fdbfe4ac89dc004f
    branch refs/heads/main

    worktree /Users/mfo/dev/dsfr-1.15.2
    HEAD 8bbfdf4b6e0000000000000000000000000000aa
    branch refs/heads/dsfr-1.15.2

    worktree /Users/mfo/dev/review-13705
    HEAD ba2b9d29620000000000000000000000000000bb
    detached

    worktree /Users/mfo/dev/locked-one
    HEAD f00fcc1ccb0000000000000000000000000000cc
    branch refs/heads/locked-one
    locked claude session (pid 26681)

    worktree /Users/mfo/dev/gone
    HEAD aaaaaaaaaa0000000000000000000000000000dd
    branch refs/heads/gone
    prunable gitdir file points to non-existent location
  OUT

  def test_parse_keeps_every_shape_including_the_ones_list_drops
    entries = E.parse(PORCELAIN)

    assert_equal 5, entries.size
    assert_equal 'main', entries[0].branch
    assert_equal 'dsfr-1.15.2', entries[1].branch

    assert entries[2].detached, 'detached worktrees must survive parsing'
    assert_nil entries[2].branch

    assert entries[3].locked
    assert_equal 'claude session (pid 26681)', entries[3].lock_reason

    assert entries[4].prunable
  end

  def test_label_falls_back_to_the_detached_head
    detached = E.parse(PORCELAIN)[2]

    assert_match(/detached ba2b9d29/, detached.label)
  end

  def test_parse_tolerates_empty_output
    assert_empty E.parse('')
  end
end

class InventoryTest < Minitest::Test
  INV = Nightshift::Core::Inventory
  WT  = Nightshift::Integrations::Worktree
  GIT = Nightshift::Integrations::Git

  def setup
    @db = Sequel.sqlite
    Sequel::Migrator.run(@db, 'db/migrations')
    @store = Nightshift::Core::Store.new(@db)
    @root = Dir.mktmpdir('nightshift-inventory')
  end

  def teardown
    FileUtils.remove_entry(@root) if @root && Dir.exist?(@root)
  end

  def repo = File.join(@root, 'demarches-simplifiees.fr')

  # Worktrees are real directories here: whether the directory still exists is
  # exactly what separates "close this worktree" from "prune a dead entry".
  def entry(name, branch: nil, missing: false, **rest)
    path = File.join(@root, name)
    FileUtils.mkdir_p(path) unless missing
    Nightshift::Core::WorktreeEntry.new(path: path, branch: branch, **rest)
  end

  def main_entry = entry('demarches-simplifiees.fr', branch: 'main')

  def pr(number, branch, state: 'OPEN', ci: 'green')
    Nightshift::Core::PR.new(number: number, branch: branch, github_state: state, ci: ci)
  end

  def scan(entries:, prs:, ghosts: [], dbs: [], merged: [], store: nil, deep: false)
    WT.stub(:entries, entries) do
      WT.stub(:ghost_dirs, ghosts) do
        WT.stub(:orphan_databases, dbs) do
          WT.stub(:database_sizes, dbs.to_h { |d| [d, 1024] }) do
            GIT.stub(:merged_branches, merged) do
              GIT.stub(:default_base, 'main') do
                INV.scan(repo_path: repo, prs: prs, store: store, deep: deep)
              end
            end
          end
        end
      end
    end
  end

  # --- the hole the whole thing exists to close -------------------------------

  def test_open_pr_without_worktree_is_reported
    report = scan(
      entries: [main_entry, entry('anchored', branch: 'anchored')],
      prs: [pr(1, 'anchored'), pr(2, 'floating')]
    )

    floating = report.prs_without_worktree
    assert_equal 1, floating.size
    assert_equal 2, floating.first.pr_number
    assert_equal 'pas de worktree local', floating.first.reason
    assert_nil floating.first.path
  end

  def test_open_prs_counts_both_anchored_and_floating
    report = scan(
      entries: [main_entry, entry('anchored', branch: 'anchored')],
      prs: [pr(1, 'anchored'), pr(2, 'floating')]
    )

    assert_equal [1, 2], report.open_prs.map(&:pr_number).sort
  end

  def test_closed_pr_without_worktree_is_not_reported
    report = scan(entries: [main_entry],
                  prs: [pr(9, 'long-gone', state: 'MERGED')])

    assert_empty report.prs_without_worktree
  end

  def test_main_worktree_is_never_an_item
    report = scan(entries: [main_entry], prs: [])

    assert_empty report.worktrees
  end

  # --- cleanup verdicts -------------------------------------------------------

  def test_worktree_of_a_merged_pr_is_closable
    report = scan(entries: [main_entry, entry('done', branch: 'done')],
                  prs: [pr(3, 'done', state: 'MERGED')])

    item = report.worktrees.first
    assert_equal Nightshift::CleanupAction::CloseWorktree, item.cleanup
    assert_equal 'PR #3 mergée', item.reason
  end

  def test_worktree_of_an_open_pr_is_left_alone
    report = scan(entries: [main_entry, entry('live', branch: 'live')],
                  prs: [pr(4, 'live')])

    assert_nil report.worktrees.first.cleanup
  end

  def test_locked_worktree_is_never_proposed_for_cleanup
    report = scan(
      entries: [main_entry,
                entry('locked', branch: 'locked', locked: true)],
      prs: [pr(5, 'locked', state: 'MERGED')]
    )

    item = report.worktrees.first
    assert_nil item.cleanup
    refute item.safe_to_clean?
  end

  def test_worktree_whose_directory_vanished_becomes_a_prune
    report = scan(entries: [main_entry,
                            entry('definitely-not-here', branch: 'ghost', missing: true)],
                  prs: [])

    item = report.worktrees.first
    assert_equal Nightshift::CleanupAction::PruneAdmin, item.cleanup
    assert item.missing_dir
  end

  # --- origin -----------------------------------------------------------------

  def test_renamed_skill_branch_is_still_recognised_as_nightshift_work
    # The real case: nightshift created auto-test-optimization-batch-623d3f73,
    # the skill renamed the branch to perf/expert-spec, and every `auto/`
    # branch-prefix filter lost the worktree for good.
    report = scan(
      entries: [main_entry,
                entry('auto-test-optimization-batch-623d3f73', branch: 'perf/expert-spec')],
      prs: []
    )

    assert_equal Nightshift::WorkItemOrigin::Auto, report.worktrees.first.origin
  end

  def test_backlog_branch_marks_the_worktree_as_nightshift_work
    @store.add_backlog('haml-migration', 'app/views/foo.html.haml')
    item = @store.claim_next('haml-migration')
    @store.update_backlog_status(item, Nightshift::BacklogStatus::Running, branch: 'weird-name')

    report = scan(entries: [main_entry, entry('weird', branch: 'weird-name')],
                  prs: [], store: @store)

    assert_equal Nightshift::WorkItemOrigin::Auto, report.worktrees.first.origin
  end

  def test_hand_made_worktree_stays_manual
    report = scan(entries: [main_entry, entry('mine', branch: 'fix-commune')],
                  prs: [])

    assert_equal Nightshift::WorkItemOrigin::Manual, report.worktrees.first.origin
  end

  # --- ghosts, databases, branches -------------------------------------------

  def test_ghost_with_a_dangling_git_is_flagged_unverifiable
    ghosts = [{ path: '/dev/degraded-mode-for-429', kind: :dangling_git,
                admin: '/dev/repo/.git/worktrees/x', verifiable: false }]
    report = scan(entries: [main_entry], prs: [], ghosts: ghosts)

    item = report.of(Nightshift::WorkItemKind::GhostDir).first
    assert item.unknown_state
    refute item.safe_to_clean?, 'a checkout git cannot vouch for must never be auto-removed'
  end

  def test_auto_husk_is_removable
    ghosts = [{ path: '/dev/auto-i18n-hardcoded-batch-11d93b2e', kind: :auto_husk,
                admin: nil, verifiable: false }]
    report = scan(entries: [main_entry], prs: [], ghosts: ghosts)

    item = report.of(Nightshift::WorkItemKind::GhostDir).first
    assert item.safe_to_clean?
    assert_equal Nightshift::CleanupAction::RemoveDir, item.cleanup
  end

  def test_orphan_databases_carry_their_size
    report = scan(entries: [main_entry], prs: [], dbs: %w[tps_test_dead])

    item = report.of(Nightshift::WorkItemKind::OrphanDb).first
    assert_equal 1024, item.size_bytes
    assert_equal Nightshift::CleanupAction::DropDatabase, item.cleanup
  end

  def test_merged_branch_checked_out_somewhere_is_not_stale
    report = scan(
      entries: [main_entry, entry('kept', branch: 'kept')],
      prs: [],
      merged: %w[kept dropped]
    )

    stale = report.of(Nightshift::WorkItemKind::StaleBranch).map(&:label)
    assert_equal %w[dropped], stale
  end

  # --- PR indexing ------------------------------------------------------------

  def test_an_open_pr_wins_over_a_closed_one_on_the_same_branch
    indexed = INV.index_prs([pr(1, 'shared', state: 'CLOSED'), pr(2, 'shared')])

    assert_equal 2, indexed['shared'].number
  end

  def test_the_most_recent_pr_wins_when_none_is_open
    old = pr(1, 'shared', state: 'CLOSED')
    old.updated_at = '2026-01-01T00:00:00Z'
    recent = pr(2, 'shared', state: 'MERGED')
    recent.updated_at = '2026-09-01T00:00:00Z'

    assert_equal 2, INV.index_prs([old, recent])['shared'].number
  end

  # --- deep pass --------------------------------------------------------------

  def test_deep_pass_blocks_a_worktree_holding_uncommitted_work
    entries = [main_entry, entry('wt-dirty', branch: 'dirty-one')]

    report = GIT.stub(:dirty?, true) do
      GIT.stub(:unpushed?, false) do
        GIT.stub(:dir_size, 4096) do
          scan(entries: entries, prs: [pr(6, 'dirty-one', state: 'MERGED')], deep: true)
        end
      end
    end

    item = report.worktrees.first
    assert item.dirty
    refute item.safe_to_clean?
    assert_includes item.blockers, 'modifs non commitées'
    assert_equal 0, report.reclaimable_bytes
  end

  def test_deep_pass_treats_an_unanswerable_git_as_unknown_not_clean
    entries = [main_entry, entry('wt-opaque', branch: 'opaque')]

    report = GIT.stub(:dirty?, nil) do
      GIT.stub(:unpushed?, nil) do
        GIT.stub(:dir_size, 4096) do
          scan(entries: entries, prs: [pr(7, 'opaque', state: 'MERGED')], deep: true)
        end
      end
    end

    assert report.worktrees.first.unknown_state
    refute report.worktrees.first.safe_to_clean?
  end

  def test_reclaimable_bytes_counts_only_what_is_safe
    entries = [main_entry, entry('wt-clean', branch: 'clean-one')]

    report = GIT.stub(:dirty?, false) do
      GIT.stub(:unpushed?, false) do
        GIT.stub(:dir_size, 4096) do
          scan(entries: entries, prs: [pr(8, 'clean-one', state: 'MERGED')], deep: true)
        end
      end
    end

    assert_equal 4096, report.reclaimable_bytes
  end

  def test_github_failure_falls_back_on_the_cached_prs
    @store.reconcile_pr(pr(11, 'cached'))

    report = Nightshift::Integrations::GitHub.stub(:fetch_prs, ->(*) { raise 'boom' }) do
      scan_without_prs
    end

    assert report.pr_fetch_failed
    assert_equal [11], report.open_prs.map(&:pr_number)
  end

  def scan_without_prs
    WT.stub(:entries, [main_entry]) do
      WT.stub(:ghost_dirs, []) do
        WT.stub(:orphan_databases, []) do
          GIT.stub(:merged_branches, []) do
            GIT.stub(:default_base, 'main') do
              INV.scan(repo_path: repo, store: @store)
            end
          end
        end
      end
    end
  end
end
