require_relative "test_helper"
require_relative "../lib/nightshift/pr"
require_relative "../lib/nightshift/store"
require_relative "../lib/nightshift/reconciler"

class FakeRenderer
  attr_reader :calls
  def initialize = @calls = []
  def update_window(pr) = @calls << [:update_window, pr.number]
  def autofix(pr) = @calls << [:autofix, pr.number]
  def propose_merge(pr) = @calls << [:propose_merge, pr.number]
  def show_comments(pr) = @calls << [:show_comments, pr.number]
  def notify_fixed(pr) = @calls << [:notify_fixed, pr.number]
end

class ReconcilerTest < Minitest::Test
  def setup
    @db = Sequel.sqlite
    Sequel::Migrator.run(@db, "db/migrations")
    @store = Nightshift::Store.new(@db)
    @renderer = FakeRenderer.new
    @reconciler = Nightshift::Reconciler.new(store: @store, renderer: @renderer)
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

  def test_transition_to_comments_triggers_show
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @reconciler.reconcile([pr])
    @renderer.calls.clear

    pr.review_count = 3
    pr.ci = nil
    @reconciler.reconcile([pr])
    assert_includes @renderer.calls, [:show_comments, 1]
  end

  def test_transition_to_changes_requested_triggers_show
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    @reconciler.reconcile([pr])
    @renderer.calls.clear

    pr.review_decision = "CHANGES_REQUESTED"
    @reconciler.reconcile([pr])
    assert_includes @renderer.calls, [:show_comments, 1]
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
end
