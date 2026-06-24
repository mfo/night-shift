# frozen_string_literal: true

require_relative 'test_helper'

require 'tempfile'
require 'json'

class SkillRunnerTest < Minitest::Test
  # --- failure_reason ---

  def test_failure_reason_success
    assert_nil Nightshift::Skills::Runner.failure_reason(true, true)
  end

  def test_failure_reason_claude_error
    assert_equal 'claude_error', Nightshift::Skills::Runner.failure_reason(false, false)
  end

  def test_failure_reason_no_diff
    assert_equal 'no_diff', Nightshift::Skills::Runner.failure_reason(true, false)
  end

  # --- count_turns ---

  def test_count_turns_nil_when_missing
    assert_nil Nightshift.count_turns('/nonexistent/path.log')
  end

  def test_count_turns_counts_assistant_messages
    log = Tempfile.new('claude.log')
    log.write('{"type":"assistant"}blah{"type":"assistant"}')
    log.close
    assert_equal 2, Nightshift.count_turns(log.path)
  ensure
    log&.unlink
  end

  # --- extract_allowed_tools ---

  def test_extract_allowed_tools_from_skill_md
    dir = Dir.mktmpdir
    skill_dir = File.join(dir, '.claude', 'skills', 'test-skill')
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, 'SKILL.md'), <<~MD)
      ---
      name: test-skill
      description: A test skill
      allowed-tools:
        - Read
        - Edit
        - "Bash(git:*)"
      ---
      # Test Skill
      Do things.
    MD

    tools = Nightshift::Skills::Runner.extract_allowed_tools('test-skill', dir)
    assert_equal %w[Read Edit Bash(git:*)], tools
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  def test_extract_allowed_tools_comma_separated
    dir = Dir.mktmpdir
    skill_dir = File.join(dir, '.claude', 'skills', 'test-skill')
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, 'SKILL.md'), <<~MD)
      ---
      name: test-skill
      description: A test
      allowed-tools:
        - "Read, Edit, Grep"
      ---
      # Body
    MD

    tools = Nightshift::Skills::Runner.extract_allowed_tools('test-skill', dir)
    assert_equal %w[Read Edit Grep], tools
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  def test_extract_allowed_tools_missing_skill_md
    dir = Dir.mktmpdir
    tools = Nightshift::Skills::Runner.extract_allowed_tools('nonexistent', dir)
    assert_equal [], tools
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  def test_extract_allowed_tools_no_frontmatter
    dir = Dir.mktmpdir
    skill_dir = File.join(dir, '.claude', 'skills', 'test-skill')
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, 'SKILL.md'), "# No frontmatter\nJust text.")

    tools = Nightshift::Skills::Runner.extract_allowed_tools('test-skill', dir)
    assert_equal [], tools
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  def test_extract_allowed_tools_no_tools_key
    dir = Dir.mktmpdir
    skill_dir = File.join(dir, '.claude', 'skills', 'test-skill')
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, 'SKILL.md'), <<~MD)
      ---
      name: test-skill
      description: no tools
      ---
      # Body
    MD

    tools = Nightshift::Skills::Runner.extract_allowed_tools('test-skill', dir)
    assert_equal [], tools
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  # --- detect_rate_limit ---

  def test_detect_rate_limit_true
    log = Tempfile.new('claude.log')
    log.puts JSON.generate(type: 'assistant', message: { content: [] })
    log.puts JSON.generate(type: 'rate_limit_event', delay: 30)
    log.close

    assert Nightshift::Skills::Runner.detect_rate_limit(log.path)
  ensure
    log&.unlink
  end

  def test_detect_rate_limit_false
    log = Tempfile.new('claude.log')
    log.puts JSON.generate(type: 'assistant', message: { content: [] })
    log.puts JSON.generate(type: 'result', result: 'done')
    log.close

    refute Nightshift::Skills::Runner.detect_rate_limit(log.path)
  ensure
    log&.unlink
  end

  def test_detect_rate_limit_missing_file
    refute Nightshift::Skills::Runner.detect_rate_limit('/nonexistent/path.log')
  end

  def test_detect_rate_limit_malformed_lines
    log = Tempfile.new('claude.log')
    log.puts 'not json'
    log.puts ''
    log.puts JSON.generate(type: 'result', result: 'ok')
    log.close

    refute Nightshift::Skills::Runner.detect_rate_limit(log.path)
  ensure
    log&.unlink
  end

  # --- KAIZEN_CATEGORIES ---

  def test_kaizen_categories_exist
    assert_equal '1-haml', Nightshift::Skills::Runner::KAIZEN_CATEGORIES['haml-migration']
    assert_equal '2-test-optimization', Nightshift::Skills::Runner::KAIZEN_CATEGORIES['test-optimization']
  end
end
