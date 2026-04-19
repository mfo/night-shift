require_relative "test_helper"
require_relative "../lib/nightshift/pr"
require_relative "../lib/nightshift/store"

class StoreTest < Minitest::Test
  def setup
    @db = Sequel.sqlite
    Sequel::Migrator.run(@db, "db/migrations")
    @store = Nightshift::Store.new(@db)
  end

  def test_upsert_creates_pr
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @store.upsert(pr)
    assert_equal "ci_green", @db[:prs].first[:state]
  end

  def test_upsert_updates_existing
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @store.upsert(pr)

    pr.ci = "red"
    @store.upsert(pr)
    assert_equal 1, @db[:prs].count
    assert_equal "ci_red", @db[:prs].first[:state]
  end

  def test_get_state
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @store.upsert(pr)
    assert_equal :ci_green, @store.get_state(1)
  end

  def test_get_state_missing
    assert_nil @store.get_state(999)
  end

  def test_reconcile_pr_first_time
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    result = @store.reconcile_pr(pr)
    refute result[:changed]
    assert_nil result[:old_state]
    assert_equal :ci_green, result[:new_state]
  end

  def test_reconcile_pr_detects_transition
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @store.reconcile_pr(pr)

    pr.ci = "red"
    result = @store.reconcile_pr(pr)
    assert result[:changed]
    assert_equal :ci_green, result[:old_state]
    assert_equal :ci_red, result[:new_state]
  end

  def test_reconcile_pr_no_change
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @store.reconcile_pr(pr)
    result = @store.reconcile_pr(pr)
    refute result[:changed]
  end

  def test_reconcile_pr_records_transition
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @store.reconcile_pr(pr)

    pr.ci = "red"
    @store.reconcile_pr(pr)

    transition = @db[:transitions].first
    assert_equal 1, transition[:pr_number]
    assert_equal "ci_green", transition[:from_state]
    assert_equal "ci_red", transition[:to_state]
  end

  def test_circuit_breaker_allows_under_max
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "red")
    @store.upsert(pr)
    ENV["NIGHTSHIFT_AUTOFIX_MAX"] = "2"
    ENV["NIGHTSHIFT_AUTOFIX_WINDOW"] = "3600"

    @store.record_run(1, kind: "autofix")
    refute @store.circuit_breaker?(1)
  end

  def test_circuit_breaker_blocks_after_max
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "red")
    @store.upsert(pr)
    ENV["NIGHTSHIFT_AUTOFIX_MAX"] = "2"
    ENV["NIGHTSHIFT_AUTOFIX_WINDOW"] = "3600"

    2.times { @store.record_run(1, kind: "autofix") }
    assert @store.circuit_breaker?(1)
  end

  def test_settings_roundtrip
    @store.set_setting("last_brief", "2026-04-18T08:00:00")
    assert_equal "2026-04-18T08:00:00", @store.get_setting("last_brief")
  end

  def test_settings_upsert
    @store.set_setting("key", "v1")
    @store.set_setting("key", "v2")
    assert_equal "v2", @store.get_setting("key")
  end

  def test_all_prs
    2.times do |i|
      pr = Nightshift::PR.new(number: i + 1, branch: "fix/bug-#{i}",
                              github_state: i == 0 ? "OPEN" : "MERGED")
      @store.upsert(pr)
    end
    assert_equal 2, @store.all_prs.size
    assert_equal 1, @store.all_prs(github_state: "OPEN").size
  end

  def test_fresh
    refute @store.fresh?(ttl: 60)
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @store.upsert(pr)
    assert @store.fresh?(ttl: 60)
  end

  # --- Backlog tests ---

  def test_add_backlog
    @store.add_backlog("haml-migration", "app/views/foo.html.haml")
    assert_equal 1, @db[:backlog_items].count
    item = @db[:backlog_items].first
    assert_equal "pending", item[:status]
    assert_equal "haml-migration", item[:skill]
  end

  def test_add_backlog_idempotent
    @store.add_backlog("haml-migration", "app/views/foo.html.haml")
    @store.add_backlog("haml-migration", "app/views/foo.html.haml")
    assert_equal 1, @db[:backlog_items].count
  end

  def test_add_backlog_different_skills_same_item
    @store.add_backlog("haml-migration", "app/views/foo.html.haml")
    @store.add_backlog("other-skill", "app/views/foo.html.haml")
    assert_equal 2, @db[:backlog_items].count
  end

  def test_claim_next_fifo
    @store.add_backlog("haml-migration", "first.haml")
    @store.add_backlog("haml-migration", "second.haml")
    item = @store.claim_next("haml-migration")
    assert_equal "first.haml", item[:item]
    assert_equal "running", item[:status]
  end

  def test_claim_next_skips_non_pending
    @store.add_backlog("haml-migration", "first.haml")
    @store.claim_next("haml-migration")
    @store.add_backlog("haml-migration", "second.haml")
    item = @store.claim_next("haml-migration")
    assert_equal "second.haml", item[:item]
  end

  def test_claim_next_returns_nil_when_empty
    assert_nil @store.claim_next("haml-migration")
  end

  def test_active_for_skill_running
    @store.add_backlog("haml-migration", "foo.haml")
    refute @store.active_for_skill?("haml-migration")
    @store.claim_next("haml-migration")
    assert @store.active_for_skill?("haml-migration")
  end

  def test_active_for_skill_pr_open
    @store.add_backlog("haml-migration", "foo.haml")
    item = @store.claim_next("haml-migration")
    @store.update_backlog_status(item[:id], "pr_open", pr_number: 42)
    assert @store.active_for_skill?("haml-migration")
  end

  def test_active_for_skill_failed_is_active
    @store.add_backlog("haml-migration", "foo.haml")
    item = @store.claim_next("haml-migration")
    @store.update_backlog_status(item[:id], "failed", failure_reason: "no_diff")
    assert @store.active_for_skill?("haml-migration")
  end

  def test_active_for_skill_done_not_active
    @store.add_backlog("haml-migration", "foo.haml")
    item = @store.claim_next("haml-migration")
    @store.update_backlog_status(item[:id], "done")
    refute @store.active_for_skill?("haml-migration")
  end

  def test_update_backlog_status_with_extras
    @store.add_backlog("haml-migration", "foo.haml")
    item = @store.claim_next("haml-migration")
    @store.update_backlog_status(item[:id], "failed", failure_reason: "no_diff")
    row = @db[:backlog_items].first
    assert_equal "failed", row[:status]
    assert_equal "no_diff", row[:failure_reason]
  end

  def test_backlog_by_branch
    @store.add_backlog("haml-migration", "foo.haml")
    item = @store.claim_next("haml-migration")
    @store.update_backlog_status(item[:id], "running", branch: "auto/haml-migration/foo")
    found = @store.backlog_by_branch("auto/haml-migration/foo")
    assert_equal "foo.haml", found[:item]
  end

  def test_backlog_by_branch_not_found
    assert_nil @store.backlog_by_branch("nope")
  end

  def test_all_backlog_filter_by_skill
    @store.add_backlog("haml-migration", "a.haml")
    @store.add_backlog("test-optimization", "b_spec.rb")
    assert_equal 1, @store.all_backlog(skill: "haml-migration").size
    assert_equal 2, @store.all_backlog.size
  end

  def test_active_for_skill_skipped_not_active
    @store.add_backlog("haml-migration", "foo.haml")
    item = @store.claim_next("haml-migration")
    @store.update_backlog_status(item[:id], "skipped")
    refute @store.active_for_skill?("haml-migration")
  end

  def test_claim_next_respects_fifo_across_statuses
    @store.add_backlog("haml-migration", "a.haml")
    @store.add_backlog("haml-migration", "b.haml")
    @store.add_backlog("haml-migration", "c.haml")

    # Claim and finish first two
    item1 = @store.claim_next("haml-migration")
    @store.update_backlog_status(item1[:id], "done")
    item2 = @store.claim_next("haml-migration")
    @store.update_backlog_status(item2[:id], "done")

    # Third should be "c.haml"
    item3 = @store.claim_next("haml-migration")
    assert_equal "c.haml", item3[:item]
  end

  def test_all_backlog_ordered_by_skill_then_created
    @store.add_backlog("test-optimization", "b_spec.rb")
    @store.add_backlog("haml-migration", "a.haml")
    @store.add_backlog("haml-migration", "z.haml")
    items = @store.all_backlog
    skills = items.map { |i| i[:skill] }
    assert_equal %w[haml-migration haml-migration test-optimization], skills
  end

  # --- Lock tests ---

  def test_acquire_lock_succeeds
    seed_pr(1)
    assert @store.acquire_lock(1, kind: "autofix")
  end

  def test_acquire_lock_blocked_when_already_held
    seed_pr(1)
    @store.acquire_lock(1, kind: "autofix")
    refute @store.acquire_lock(1, kind: "autofix")
  end

  def test_acquire_lock_different_pr_not_blocked
    seed_pr(1)
    seed_pr(2)
    @store.acquire_lock(1, kind: "autofix")
    assert @store.acquire_lock(2, kind: "autofix")
  end

  def test_acquire_lock_different_kind_not_blocked
    seed_pr(1)
    @store.acquire_lock(1, kind: "autofix")
    assert @store.acquire_lock(1, kind: "ci_red")
  end

  def test_release_lock_allows_reacquire
    seed_pr(1)
    @store.acquire_lock(1, kind: "autofix")
    @store.release_lock(1, kind: "autofix", success: true)
    assert @store.acquire_lock(1, kind: "autofix")
  end

  def test_release_lock_records_success
    seed_pr(1)
    @store.acquire_lock(1, kind: "autofix")
    @store.release_lock(1, kind: "autofix", success: true)

    run = @db[:runs].order(:id).last
    refute_nil run[:finished_at]
    assert run[:success]
  end

  def test_release_lock_records_failure
    seed_pr(1)
    @store.acquire_lock(1, kind: "autofix")
    @store.release_lock(1, kind: "autofix", success: false)

    run = @db[:runs].order(:id).last
    refute run[:success]
  end

  def test_zombie_lock_expired_after_timeout
    seed_pr(1)
    @store.acquire_lock(1, kind: "autofix")

    # Simulate zombie: backdate started_at
    @db[:runs].update(started_at: Time.now.to_i - 1000)

    # New acquire with short timeout should expire the zombie
    assert @store.acquire_lock(1, kind: "autofix", timeout: 900)
  end

  def test_with_lock_yields_and_releases
    seed_pr(1)
    called = false
    @store.with_lock(1, kind: "autofix") { called = true }

    assert called
    # Lock released — can reacquire
    assert @store.acquire_lock(1, kind: "autofix")
  end

  def test_with_lock_returns_false_when_locked
    seed_pr(1)
    @store.acquire_lock(1, kind: "autofix")

    called = false
    result = @store.with_lock(1, kind: "autofix") { called = true }

    refute called
    assert_equal false, result
  end

  def test_with_lock_releases_on_exception
    seed_pr(1)
    assert_raises(RuntimeError) do
      @store.with_lock(1, kind: "autofix") { raise "boom" }
    end

    # Lock released despite exception
    assert @store.acquire_lock(1, kind: "autofix")
    # The failed run should be finished (only the new acquire is open)
    assert_equal 1, @db[:runs].where(success: false).count
  end

  def test_with_lock_passes_result_for_extras
    seed_pr(1)
    @store.with_lock(1, kind: "autofix") do |result|
      result[:turns_used] = 12
      result[:files_changed] = 3
      result[:output_path] = "/tmp/claude.log"
    end

    run = @db[:runs].order(:id).last
    assert_equal 12, run[:turns_used]
    assert_equal 3, run[:files_changed]
    assert_equal "/tmp/claude.log", run[:output_path]
    assert run[:success]
  end

  def test_with_lock_extras_preserved_on_failure
    seed_pr(1)
    assert_raises(RuntimeError) do
      @store.with_lock(1, kind: "autofix") do |result|
        result[:turns_used] = 5
        result[:files_changed] = 0
        raise "spec failure"
      end
    end

    run = @db[:runs].order(:id).last
    assert_equal 5, run[:turns_used]
    assert_equal 0, run[:files_changed]
    refute run[:success]
  end

  private

  def seed_pr(number)
    pr = Nightshift::PR.new(number: number, branch: "fix/bug-#{number}",
                            github_state: "OPEN", ci: "red")
    @store.upsert(pr)
  end
end
