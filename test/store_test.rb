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
end
