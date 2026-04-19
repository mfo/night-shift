require_relative "test_helper"
require_relative "../lib/nightshift/pr"
require_relative "../lib/nightshift/brief"

class BriefTest < Minitest::Test
  def test_actions_for_ci_red_only
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "red")
    lines = Nightshift::Brief.actions_for(pr)
    assert_equal 1, lines.size
    assert_match(/CI rouge/, lines[0])
  end

  def test_actions_for_ci_red_with_comments
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "red",
                            review_count: 2)
    lines = Nightshift::Brief.actions_for(pr)
    assert_equal 2, lines.size
    assert_match(/CI rouge/, lines[0])
    assert_match(/2 comment/, lines[1])
  end

  def test_actions_for_approved
    pr = Nightshift::PR.new(number: 42, branch: "fix/bug",
                            github_state: "OPEN", ci: "green",
                            review_decision: "APPROVED")
    lines = Nightshift::Brief.actions_for(pr)
    assert_equal 1, lines.size
    assert_match(/nightshift merge 42/, lines[0])
  end

  def test_actions_for_changes_requested_with_comments
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN",
                            review_decision: "CHANGES_REQUESTED",
                            review_count: 3)
    lines = Nightshift::Brief.actions_for(pr)
    assert_equal 2, lines.size
    assert_match(/changes requested/, lines[0])
    assert_match(/3 comment/, lines[1])
  end

  def test_actions_for_comments_only
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green",
                            review_count: 1)
    lines = Nightshift::Brief.actions_for(pr)
    assert_equal 1, lines.size
    assert_match(/1 comment/, lines[0])
  end

  def test_actions_for_no_action
    pr = Nightshift::PR.new(number: 1, branch: "fix/bug",
                            github_state: "OPEN", ci: "green")
    lines = Nightshift::Brief.actions_for(pr)
    assert_empty lines
  end

  # --- pane_brief_for ---

  def test_pane_brief_for_includes_header
    pr = Nightshift::PR.new(number: 42, branch: "fix/login",
                            github_state: "OPEN", ci: "green")
    text = Nightshift::Brief.pane_brief_for(pr)
    assert_includes text, "#42"
    assert_includes text, "login"
    assert_includes text, "ci: green"
  end

  def test_pane_brief_for_includes_actions
    pr = Nightshift::PR.new(number: 10, branch: "fix/bug",
                            github_state: "OPEN", ci: "red")
    text = Nightshift::Brief.pane_brief_for(pr)
    assert_includes text, "CI rouge"
  end

  # --- parse_inventory ---

  def test_parse_inventory
    content = <<~MD
      | U01 | `spec/controllers/api/v2/graphql_controller_n+1_spec.rb` | :70 | 23.55s | 3 | 48.31% | | | | |
      | U03 | `spec/models/dossier_spec.rb` | :2645 | 5.93s | 5 | 55.68% | ✅ T08 | 64.03s | 54.79s | -14.4% |
      | S01 | `spec/system/routing/rules_full_scenario_spec.rb` | :49 | 66.41s | 2 | 55.10% | | | | |
      some random text that should be ignored
    MD
    entries = Nightshift::CLI.parse_inventory(content)
    assert_equal 3, entries.size
    assert_equal "spec/system/routing/rules_full_scenario_spec.rb", entries[2][:file]
    assert_equal 6641, entries[2][:priority]
    assert_equal 2355, entries[0][:priority]
  end

  def test_pane_brief_for_approved_no_comments
    pr = Nightshift::PR.new(number: 5, branch: "feat/new",
                            github_state: "OPEN", ci: "green",
                            review_decision: "APPROVED")
    text = Nightshift::Brief.pane_brief_for(pr)
    assert_includes text, "nightshift merge 5"
    assert_includes text, "review: APPROVED"
  end
end
