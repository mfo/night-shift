require_relative "test_helper"
require_relative "../lib/nightshift/pr"
require_relative "../lib/nightshift/store"
require_relative "../lib/nightshift/reconciler"

class FakeRenderer
  attr_reader :calls
  def initialize = @calls = []
  def run_in_window(branch, cmd) = @calls << [:run_in_window, branch, cmd]
  def close_worktree(branch) = @calls << [:close_worktree, branch]
  def update_window(pr) = @calls << [:update_window, pr.number]
  def autofix(pr) = @calls << [:autofix, pr.number]
  def propose_merge(pr) = @calls << [:propose_merge, pr.number]
  def show_comments(pr) = @calls << [:show_comments, pr.number]
  def notify_fixed(pr) = @calls << [:notify_fixed, pr.number]
  def propose_cleanup(pr) = @calls << [:propose_cleanup, pr.number]
end

class ReconcilerTest < Minitest::Test
  def setup
    @db = Sequel.sqlite
    Sequel::Migrator.run(@db, "db/migrations")
    @store = Nightshift::Store.new(@db)
    @renderer = FakeRenderer.new
    # Pass all test branches so worktree-centric filter doesn't block
    @all_branches = Set.new(%w[fix/bug fix/a fix/b fix/bug-1 fix/bug-2
                               auto/haml-migration/views-foo auto/haml-migration/views-bar
                               auto/haml-migration/a fix/unrelated])
    @reconciler = Nightshift::Reconciler.new(store: @store, renderer: @renderer,
                                             worktree_branches: @all_branches)
  end

  def test_first_reconcile_no_transition
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @reconciler.reconcile([pr])
    assert_equal [[:update_window, 1]], @renderer.calls
  end

  def test_transition_to_ci_red_triggers_autofix
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @reconciler.reconcile([pr])
    @renderer.calls.clear

    pr.ci = "red"
    @reconciler.reconcile([pr])
    assert_includes @renderer.calls, [:autofix, 1]
    assert_includes @renderer.calls, [:update_window, 1]
  end

  def test_transition_to_approved_triggers_merge
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @reconciler.reconcile([pr])
    @renderer.calls.clear

    pr.review_decision = "APPROVED"
    @reconciler.reconcile([pr])
    assert_includes @renderer.calls, [:propose_merge, 1]
  end

  def test_transition_to_comments_state_no_show_without_delta
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @reconciler.reconcile([pr])
    @renderer.calls.clear

    pr.review_count = 3
    pr.ci = nil
    @reconciler.reconcile([pr])
    # show_comments is driven by comment_delta, not state transitions
    refute @renderer.calls.any? { |c| c[0] == :show_comments }
  end

  def test_transition_to_changes_requested_no_show_without_delta
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @reconciler.reconcile([pr])
    @renderer.calls.clear

    pr.review_decision = "CHANGES_REQUESTED"
    @reconciler.reconcile([pr])
    # show_comments is driven by comment_delta, not state transitions
    refute @renderer.calls.any? { |c| c[0] == :show_comments }
  end

  def test_comment_delta_triggers_show_comments
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green", comment_count: 0)
    @reconciler.reconcile([pr])
    @renderer.calls.clear

    pr.comment_count = 3
    @reconciler.reconcile([pr])
    assert_includes @renderer.calls, [:show_comments, 1]
  end

  def test_no_comment_delta_no_show_comments
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green", comment_count: 2)
    @reconciler.reconcile([pr])
    @renderer.calls.clear

    # Same comment_count — no delta
    @reconciler.reconcile([pr])
    refute @renderer.calls.any? { |c| c[0] == :show_comments }
  end

  def test_comments_shown_before_transitions
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green", comment_count: 0)
    @reconciler.reconcile([pr])
    @renderer.calls.clear

    # Both comment delta AND state transition
    pr.comment_count = 2
    pr.ci = "red"
    @reconciler.reconcile([pr])

    comment_idx = @renderer.calls.index { |c| c[0] == :show_comments }
    autofix_idx = @renderer.calls.index { |c| c[0] == :autofix }
    assert comment_idx, "show_comments should be called"
    assert autofix_idx, "autofix should be called"
    assert comment_idx < autofix_idx, "show_comments should come before autofix"
  end

  def test_ci_red_to_green_triggers_notify
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "red")
    @reconciler.reconcile([pr])
    @renderer.calls.clear

    pr.ci = "green"
    @reconciler.reconcile([pr])
    assert_includes @renderer.calls, [:notify_fixed, 1]
  end

  def test_no_reaction_on_stable_state
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @reconciler.reconcile([pr])
    @renderer.calls.clear

    @reconciler.reconcile([pr])
    assert_equal [[:update_window, 1]], @renderer.calls
  end

  def test_multiple_prs
    pr1 = Nightshift::PR.new(number: 1, branch: "fix/a", github_state: "OPEN", ci: "green")
    pr2 = Nightshift::PR.new(number: 2, branch: "fix/b", github_state: "OPEN", ci: "red")
    @reconciler.reconcile([pr1, pr2])
    assert_equal 2, @renderer.calls.count { |c| c[0] == :update_window }
  end

  def test_lock_prevents_double_autofix
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @reconciler.reconcile([pr])
    @renderer.calls.clear

    # Simulate: autofix already running (lock held externally by Autofix.run)
    @store.acquire_lock(1, kind: "ci_red")

    # Force a transition to ci_red
    pr.ci = "red"
    @reconciler.reconcile([pr])

    # Autofix should NOT trigger because lock is held
    refute @renderer.calls.any? { |c| c[0] == :autofix },
           "autofix should not trigger while lock is held"
    assert_includes @renderer.calls, [:update_window, 1]
  end

  # --- Backlog / skill loop tests ---

  def test_reconcile_skills_detect_merge_marks_done
    @store.add_backlog("haml-migration", "app/views/foo.html.haml")
    item = @store.claim_next("haml-migration")
    @store.update_backlog_status(item[:id], "pr_open",
      branch: "auto/haml-migration/views-foo", pr_number: 42)

    pr = Nightshift::PR.new(number: 42, branch: "auto/haml-migration/views-foo",
                            github_state: "MERGED")
    @store.reconcile_pr(pr)
    @reconciler.reconcile([pr])

    updated = @db[:backlog_items].where(id: item[:id]).first
    assert_equal "done", updated[:status]
  end

  def test_reconcile_skills_ignores_non_backlog_prs
    pr = Nightshift::PR.new(number: 99, branch: "fix/unrelated",
                            github_state: "MERGED")
    @store.reconcile_pr(pr)
    @reconciler.reconcile([pr])
    # Should not crash
  end

  def test_active_for_skill_blocks_pick
    @store.add_backlog("haml-migration", "a.haml")
    @store.add_backlog("haml-migration", "b.haml")
    @store.claim_next("haml-migration")
    assert @store.active_for_skill?("haml-migration")
  end

  def test_failed_item_does_not_block_pick
    @store.add_backlog("haml-migration", "a.haml")
    @store.add_backlog("haml-migration", "b.haml")
    item = @store.claim_next("haml-migration")
    @store.update_backlog_status(item[:id], "failed", failure_reason: "test")
    refute @store.active_for_skill?("haml-migration"),
           "failed item should not block new picks"
  end

  def test_skipped_item_unblocks_pick
    @store.add_backlog("haml-migration", "a.haml")
    @store.add_backlog("haml-migration", "b.haml")
    item = @store.claim_next("haml-migration")
    @store.update_backlog_status(item[:id], "failed", failure_reason: "test")
    @store.update_backlog_status(item[:id], "skipped")
    refute @store.active_for_skill?("haml-migration"),
           "skipped item should not block new picks"
  end

  # --- Cleanup tests ---

  def test_transition_to_merged_triggers_cleanup
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @reconciler.reconcile([pr])
    @renderer.calls.clear

    pr.github_state = "MERGED"
    @reconciler.reconcile([pr])
    assert_includes @renderer.calls, [:propose_cleanup, 1]
  end

  def test_transition_to_deployed_triggers_cleanup
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @reconciler.reconcile([pr])
    @renderer.calls.clear

    pr.github_state = "MERGED"
    pr.deployed = true
    @reconciler.reconcile([pr])
    assert_includes @renderer.calls, [:propose_cleanup, 1]
  end

  # --- Zombie recovery tests ---

  def test_zombie_recovery_resets_to_pending
    @store.add_backlog("haml-migration", "app/views/foo.html.haml")
    item = @store.claim_next("haml-migration")
    @store.update_backlog_status(item[:id], "running",
      branch: "auto/haml-migration/views-foo")

    # Add a pr_open item to block pick_next_items from re-claiming
    @store.add_backlog("haml-migration", "app/views/bar.html.haml")
    bar = @store.claim_next("haml-migration")
    @store.update_backlog_status(bar[:id], "pr_open",
      branch: "auto/haml-migration/views-bar")

    # Reconcile with worktree_branches that do NOT include the zombie branch
    branches_without_zombie = Set.new(%w[fix/bug auto/haml-migration/views-bar])
    reconciler = Nightshift::Reconciler.new(store: @store, renderer: @renderer,
                                            worktree_branches: branches_without_zombie)
    reconciler.reconcile([])

    updated = @db[:backlog_items].where(id: item[:id]).first
    assert_equal "pending", updated[:status]
    assert_nil updated[:branch]
    assert_equal 1, updated[:retry_count]
  end

  def test_zombie_recovery_skips_when_retries_exhausted
    @store.add_backlog("haml-migration", "app/views/foo.html.haml")
    item = @store.claim_next("haml-migration")
    @store.update_backlog_status(item[:id], "running",
      branch: "auto/haml-migration/views-foo")
    @db[:backlog_items].where(id: item[:id]).update(retry_count: 3)

    branches_without_zombie = Set.new(%w[fix/bug fix/other])
    reconciler = Nightshift::Reconciler.new(store: @store, renderer: @renderer,
                                            worktree_branches: branches_without_zombie)
    reconciler.reconcile([])

    updated = @db[:backlog_items].where(id: item[:id]).first
    assert_equal "skipped", updated[:status]
    assert_equal "zombie_exhausted", updated[:failure_reason]
  end

  def test_zombie_recovery_ignores_running_with_active_worktree
    @store.add_backlog("haml-migration", "app/views/foo.html.haml")
    item = @store.claim_next("haml-migration")
    @store.update_backlog_status(item[:id], "running",
      branch: "auto/haml-migration/views-foo")

    # Worktree exists — should NOT recover
    @reconciler.reconcile([])

    updated = @db[:backlog_items].where(id: item[:id]).first
    assert_equal "running", updated[:status]
  end

  def test_zombie_recovery_skips_items_without_branch
    @store.add_backlog("haml-migration", "app/views/foo.html.haml")
    item = @store.claim_next("haml-migration")
    # Running but no branch assigned yet (edge case: claimed but not launched)
    assert_nil item[:branch]

    branches = Set.new(%w[fix/bug])
    reconciler = Nightshift::Reconciler.new(store: @store, renderer: @renderer,
                                            worktree_branches: branches)
    reconciler.reconcile([])

    updated = @db[:backlog_items].where(id: item[:id]).first
    assert_equal "running", updated[:status], "should not touch running items with nil branch"
  end

  # --- handle_done tests ---

  def test_handle_done_closes_worktree_via_renderer
    @store.add_backlog("haml-migration", "app/views/foo.html.haml")
    item = @store.claim_next("haml-migration")
    @store.update_backlog_status(item[:id], "pr_open",
      branch: "auto/haml-migration/views-foo", pr_number: 42)

    pr = Nightshift::PR.new(number: 42, branch: "auto/haml-migration/views-foo",
                            github_state: "MERGED")
    @store.reconcile_pr(pr)
    @reconciler.reconcile([pr])

    assert_includes @renderer.calls, [:close_worktree, "auto/haml-migration/views-foo"]
  end

  def test_handle_done_ignores_pr_open_not_merged
    @store.add_backlog("haml-migration", "app/views/foo.html.haml")
    item = @store.claim_next("haml-migration")
    @store.update_backlog_status(item[:id], "pr_open",
      branch: "auto/haml-migration/views-foo", pr_number: 42)

    pr = Nightshift::PR.new(number: 42, branch: "auto/haml-migration/views-foo",
                            github_state: "OPEN", ci: "green")
    @store.reconcile_pr(pr)
    @reconciler.reconcile([pr])

    updated = @db[:backlog_items].where(id: item[:id]).first
    assert_equal "pr_open", updated[:status]
  end

  # --- Worktree-centric filter tests ---

  def test_worktree_centric_filter_ignores_prs_without_worktree
    # PR exists but branch is NOT in worktree_branches
    branches = Set.new(%w[fix/a])
    reconciler = Nightshift::Reconciler.new(store: @store, renderer: @renderer,
                                            worktree_branches: branches)

    pr_in = Nightshift::PR.new(number: 1, branch: "fix/a", github_state: "OPEN", ci: "green")
    pr_out = Nightshift::PR.new(number: 2, branch: "fix/no-worktree", github_state: "OPEN", ci: "red")
    reconciler.reconcile([pr_in, pr_out])

    # Only pr_in should be updated
    assert_equal [[:update_window, 1]], @renderer.calls
    assert_nil @store.get_state(2)
  end

  # --- Backlog lifecycle full cycle ---

  def test_full_backlog_lifecycle_pending_to_done
    # pending → claim → running → pr_open → merged → done
    @store.add_backlog("haml-migration", "app/views/bar.html.haml")
    item = @store.claim_next("haml-migration")
    assert_equal "running", item[:status]

    @store.update_backlog_status(item[:id], "running",
      branch: "auto/haml-migration/views-bar")
    @store.update_backlog_status(item[:id], "pr_open",
      branch: "auto/haml-migration/views-bar", pr_number: 99)

    pr = Nightshift::PR.new(number: 99, branch: "auto/haml-migration/views-bar",
                            github_state: "MERGED")
    @store.reconcile_pr(pr)
    @reconciler.reconcile([pr])

    updated = @db[:backlog_items].where(id: item[:id]).first
    assert_equal "done", updated[:status]
  end

  def test_full_backlog_lifecycle_zombie_to_retry
    # pending → claim → running → zombie_recovered (reset to pending) → re-claimable
    @store.add_backlog("haml-migration", "a.haml")
    @store.add_backlog("haml-migration", "b.haml")
    item = @store.claim_next("haml-migration")
    @store.update_backlog_status(item[:id], "running",
      branch: "auto/haml-migration/a")

    # Add a pr_open blocker so pick_next_items doesn't interfere
    blocker = @store.claim_next("haml-migration")
    @store.update_backlog_status(blocker[:id], "pr_open",
      branch: "auto/haml-migration/views-bar")

    # Worktree for zombie disappears, blocker worktree stays
    branches = Set.new(%w[fix/other auto/haml-migration/views-bar])
    reconciler = Nightshift::Reconciler.new(store: @store, renderer: @renderer,
                                            worktree_branches: branches)
    reconciler.reconcile([])

    updated = @db[:backlog_items].where(id: item[:id]).first
    assert_equal "pending", updated[:status]
    assert_nil updated[:branch]
    assert_equal 1, updated[:retry_count]

    # pr_open still blocks
    assert @store.active_for_skill?("haml-migration")
  end

  # --- Multiple transitions in sequence ---

  def test_rapid_state_changes
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @reconciler.reconcile([pr])

    # green → red → green → approved (3 transitions)
    pr.ci = "red"
    @reconciler.reconcile([pr])

    pr.ci = "green"
    @reconciler.reconcile([pr])

    pr.review_decision = "APPROVED"
    @reconciler.reconcile([pr])

    transitions = @db[:transitions].where(pr_number: 1).all
    assert_equal 3, transitions.size
    assert_equal "ci_green", transitions[0][:from_state]
    assert_equal "ci_red", transitions[0][:to_state]
    assert_equal "ci_red", transitions[1][:from_state]
    assert_equal "ci_green", transitions[1][:to_state]
    assert_equal "ci_green", transitions[2][:from_state]
    assert_equal "approved", transitions[2][:to_state]
  end

  # --- Lock tests ---

  def test_lock_released_allows_transition
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @reconciler.reconcile([pr])

    # Lock held then released (simulates autofix completed)
    @store.acquire_lock(1, kind: "ci_red")
    @store.release_lock(1, kind: "ci_red")

    # Transition to ci_red — should trigger because lock was released
    @renderer.calls.clear
    pr.ci = "red"
    @reconciler.reconcile([pr])
    assert_includes @renderer.calls, [:autofix, 1]
  end
end
