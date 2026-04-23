require_relative "test_helper"
require_relative "../lib/nightshift/skill_runner"

require "tempfile"

class SkillRunnerTest < Minitest::Test
  def test_failure_reason_success
    assert_nil Nightshift::SkillRunner.failure_reason(true, true)
  end

  def test_failure_reason_claude_error
    assert_equal "claude_error", Nightshift::SkillRunner.failure_reason(false, false)
  end

  def test_failure_reason_no_diff
    assert_equal "no_diff", Nightshift::SkillRunner.failure_reason(true, false)
  end

  def test_count_turns_nil_when_missing
    assert_nil Nightshift.count_turns("/nonexistent/path.log")
  end

  def test_count_turns_counts_assistant_messages
    log = Tempfile.new("claude.log")
    log.write('{"type":"assistant"}blah{"type":"assistant"}')
    log.close
    assert_equal 2, Nightshift.count_turns(log.path)
  ensure
    log&.unlink
  end
end
