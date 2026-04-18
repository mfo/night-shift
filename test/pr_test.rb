require_relative "test_helper"
require_relative "../lib/nightshift/pr"

class PRTest < Minitest::Test
  def test_all_11_states
    cases = {
      { github_state: "MERGED", deployed: true } => :deployed,
      { github_state: "MERGED" } => :merged,
      { github_state: "CLOSED" } => :closed,
      { github_state: "OPEN", ci: "red" } => :ci_red,
      { github_state: "OPEN", review_decision: "CHANGES_REQUESTED" } => :changes_requested,
      { github_state: "OPEN", auto_merge: true } => :auto_merging,
      { github_state: "OPEN", review_decision: "APPROVED" } => :approved,
      { github_state: "OPEN", review_count: 2 } => :has_comments,
      { github_state: "OPEN", ci: "green" } => :ci_green,
      { github_state: "OPEN", ci: "running" } => :ci_running,
      {} => :draft,
    }
    cases.each do |attrs, expected|
      pr = Nightshift::PR.new(**attrs)
      assert_equal expected, pr.state, "Expected #{expected} for #{attrs}"
    end
  end

  def test_ci_red_trumps_approved
    pr = Nightshift::PR.new(github_state: "OPEN", ci: "red",
                            review_decision: "APPROVED")
    assert_equal :ci_red, pr.state
  end

  def test_approved_trumps_comments
    pr = Nightshift::PR.new(github_state: "OPEN", ci: "green",
                            review_decision: "APPROVED", review_count: 3)
    assert_equal :approved, pr.state
  end

  def test_deployed_trumps_merged
    pr = Nightshift::PR.new(github_state: "MERGED", deployed: true)
    assert_equal :deployed, pr.state
  end

  def test_window_name_with_pr
    pr = Nightshift::PR.new(number: 42, branch: "feat/dark-mode",
                            github_state: "OPEN", ci: "green")
    assert_equal "🟢 #42 dark-mode", pr.window_name
  end

  def test_window_name_without_pr
    pr = Nightshift::PR.new(branch: "feat/dark-mode")
    assert_equal "🔨 dark-mode", pr.window_name
  end

  def test_badge_combined
    pr = Nightshift::PR.new(github_state: "OPEN", ci: "red",
                            review_decision: "APPROVED")
    assert_equal "🔴✅", pr.badge
  end

  def test_badge_terminal_states
    pr = Nightshift::PR.new(github_state: "MERGED")
    assert_equal "🗑", pr.badge
  end

  def test_slug_strips_prefix
    pr = Nightshift::PR.new(branch: "US/long-branch-name-here")
    assert_equal "long-branch-name-here", pr.slug
  end

  def test_slug_truncates_at_35
    pr = Nightshift::PR.new(branch: "feat/this-is-a-very-long-branch-name-that-should-be-truncated")
    assert_equal 35, pr.slug.length
  end

  def test_emoji_matches_state
    Nightshift::PR::STATES.each do |s|
      assert Nightshift::PR::EMOJI.key?(s), "Missing emoji for state #{s}"
    end
  end
end
