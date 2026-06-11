require_relative "test_helper"

class BriefTest < Minitest::Test
  def test_actions_for_ci_red_only
    pr = Nightshift::Core::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "red")
    lines = Nightshift::Monitoring::Brief.actions_for(pr)
    assert_equal 1, lines.size
    assert_match(/CI rouge/, lines[0])
  end

  def test_actions_for_ci_red_with_comments
    pr = Nightshift::Core::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "red",
                            review_count: 2)
    lines = Nightshift::Monitoring::Brief.actions_for(pr)
    assert_equal 2, lines.size
    assert_match(/CI rouge/, lines[0])
    assert_match(/2 comment/, lines[1])
  end

  def test_actions_for_approved
    pr = Nightshift::Core::PR.new(number: 42, branch: "fix/bug",
                            github_state: "OPEN", ci: "green",
                            review_decision: "APPROVED")
    lines = Nightshift::Monitoring::Brief.actions_for(pr)
    assert_equal 1, lines.size
    assert_match(/nightshift merge 42/, lines[0])
  end

  def test_actions_for_changes_requested_with_comments
    pr = Nightshift::Core::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN",
                            review_decision: "CHANGES_REQUESTED",
                            review_count: 3)
    lines = Nightshift::Monitoring::Brief.actions_for(pr)
    assert_equal 2, lines.size
    assert_match(/changes requested/, lines[0])
    assert_match(/3 comment/, lines[1])
  end

  def test_actions_for_comments_only
    pr = Nightshift::Core::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green",
                            review_count: 1)
    lines = Nightshift::Monitoring::Brief.actions_for(pr)
    assert_equal 1, lines.size
    assert_match(/1 comment/, lines[0])
  end

  def test_actions_for_no_action
    pr = Nightshift::Core::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    lines = Nightshift::Monitoring::Brief.actions_for(pr)
    assert_empty lines
  end

  # --- pane_brief_for ---

  def test_pane_brief_for_includes_header
    pr = Nightshift::Core::PR.new(number: 42, branch: "fix/login",
                            github_state: "OPEN", ci: "green")
    text = Nightshift::Monitoring::Brief.pane_brief_for(pr)
    assert_includes text, "#42"
    assert_includes text, "login"
    assert_includes text, "ci: green"
  end

  def test_pane_brief_for_includes_actions
    pr = Nightshift::Core::PR.new(number: 10, branch: "fix/bug",
                            github_state: "OPEN", ci: "red")
    text = Nightshift::Monitoring::Brief.pane_brief_for(pr)
    assert_includes text, "CI rouge"
  end



  def test_pane_brief_for_approved_no_comments
    pr = Nightshift::Core::PR.new(number: 5, branch: "feat/new",
                            github_state: "OPEN", ci: "green",
                            review_decision: "APPROVED")
    text = Nightshift::Monitoring::Brief.pane_brief_for(pr)
    assert_includes text, "nightshift merge 5"
    assert_includes text, "review: APPROVED"
  end
end
