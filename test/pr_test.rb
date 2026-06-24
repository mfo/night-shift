# frozen_string_literal: true

require_relative 'test_helper'

class PRTest < Minitest::Test
  def test_all_11_states
    ps = Nightshift::PRState
    cases = {
      { github_state: 'MERGED', deployed: true } => ps::Deployed,
      { github_state: 'MERGED' } => ps::Merged,
      { github_state: 'CLOSED' } => ps::Closed,
      { github_state: 'OPEN', ci: 'red' } => ps::CiRed,
      { github_state: 'OPEN', review_decision: 'CHANGES_REQUESTED' } => ps::ChangesRequested,
      { github_state: 'OPEN', auto_merge: true } => ps::AutoMerging,
      { github_state: 'OPEN', review_decision: 'APPROVED' } => ps::Approved,
      { github_state: 'OPEN', review_count: 2 } => ps::HasComments,
      { github_state: 'OPEN', ci: 'green' } => ps::CiGreen,
      { github_state: 'OPEN', ci: 'running' } => ps::CiRunning,
      {} => ps::Draft
    }
    cases.each do |attrs, expected|
      pr = Nightshift::Core::PR.new(**attrs)
      assert_equal expected, pr.state, "Expected #{expected} for #{attrs}"
    end
  end

  def test_ci_red_trumps_approved
    pr = Nightshift::Core::PR.new(github_state: 'OPEN', ci: 'red',
                                  review_decision: 'APPROVED')
    assert_equal Nightshift::PRState::CiRed, pr.state
  end

  def test_approved_trumps_comments
    pr = Nightshift::Core::PR.new(github_state: 'OPEN', ci: 'green',
                                  review_decision: 'APPROVED', review_count: 3)
    assert_equal Nightshift::PRState::Approved, pr.state
  end

  def test_deployed_trumps_merged
    pr = Nightshift::Core::PR.new(github_state: 'MERGED', deployed: true)
    assert_equal Nightshift::PRState::Deployed, pr.state
  end

  def test_window_name_with_pr
    pr = Nightshift::Core::PR.new(number: 42, branch: 'feat/dark-mode',
                                  github_state: 'OPEN', ci: 'green')
    assert_equal '🟢 #42 dark-mode', pr.window_name
  end

  def test_window_name_without_pr
    pr = Nightshift::Core::PR.new(branch: 'feat/dark-mode')
    assert_equal '🔨 dark-mode', pr.window_name
  end

  def test_badge_combined
    pr = Nightshift::Core::PR.new(github_state: 'OPEN', ci: 'red',
                                  review_decision: 'APPROVED')
    assert_equal '🔴✅', pr.badge
  end

  def test_badge_terminal_states
    pr = Nightshift::Core::PR.new(github_state: 'MERGED')
    assert_equal '🗑', pr.badge
  end

  def test_slug_strips_prefix
    pr = Nightshift::Core::PR.new(branch: 'US/long-branch-name-here')
    assert_equal 'long-branch-name-here', pr.slug
  end

  def test_slug_truncates_at_35
    pr = Nightshift::Core::PR.new(branch: 'feat/this-is-a-very-long-branch-name-that-should-be-truncated')
    assert_equal 35, pr.slug.length
  end

  def test_emoji_matches_state
    Nightshift::PRState.values.each do |s|
      assert Nightshift::Core::PR::EMOJI.key?(s), "Missing emoji for state #{s}"
    end
  end
end
