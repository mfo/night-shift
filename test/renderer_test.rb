require_relative "test_helper"
require_relative "../lib/nightshift/pr"
require_relative "../lib/nightshift/renderer"

class RendererTest < Minitest::Test
  def setup
    @renderer = Nightshift::Renderer.new(session: "test-session")
  end

  def test_pane_brief_line_full
    pr = Nightshift::PR.new(number: 42, branch: "fix/login-bug",
                            github_state: "OPEN", ci: "green",
                            review_decision: "APPROVED", reviewer: "alice",
                            updated_at: "2026-04-19T10:00:00Z")
    line = @renderer.pane_brief_line(pr)
    assert_includes line, "#42"
    assert_includes line, "login-bug"
    assert_includes line, "by:alice"
    assert_includes line, "2026-04-19"
  end

  def test_pane_brief_line_no_reviewer
    pr = Nightshift::PR.new(number: 10, branch: "feat/new-feature",
                            github_state: "OPEN", ci: "red")
    line = @renderer.pane_brief_line(pr)
    assert_includes line, "#10"
    refute_includes line, "by:"
  end

  def test_pane_brief_line_ci_red_with_comments
    pr = Nightshift::PR.new(number: 5, branch: "fix/perf",
                            github_state: "OPEN", ci: "red",
                            review_count: 3, reviewer: "bob")
    line = @renderer.pane_brief_line(pr)
    assert_includes line, "#5"
    assert_includes line, "by:bob"
  end
end
