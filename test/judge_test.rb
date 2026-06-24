# frozen_string_literal: true

require_relative 'test_helper'

require 'tempfile'
require 'json'

class JudgeTest < Minitest::Test
  # --- parse_verdict ---

  def test_parse_verdict_valid_json
    raw = '{"verdict":"skill_defect","root_cause":"missing tool","fixable_by_skill_update":true,"suggested_patch":"add Read","confidence":0.9}'
    result = Nightshift::CI::Judge.parse_verdict(raw)
    assert_equal Nightshift::VerdictName::SkillDefect, result.verdict
    assert_equal 'missing tool', result.root_cause
    assert_equal true, result.fixable_by_skill_update
    assert_equal 'add Read', result.suggested_patch
    assert_in_delta 0.9, result.confidence
  end

  def test_parse_verdict_with_surrounding_text
    raw = "Here is my analysis:\n```json\n{\"verdict\":\"item_hard\",\"root_cause\":\"complex\",\"fixable_by_skill_update\":false,\"suggested_patch\":null,\"confidence\":0.7}\n```\nThat's it."
    result = Nightshift::CI::Judge.parse_verdict(raw)
    assert_equal Nightshift::VerdictName::ItemHard, result.verdict
    assert_equal 'complex', result.root_cause
    assert_in_delta 0.7, result.confidence
  end

  def test_parse_verdict_nested_json
    raw = '{"verdict":"infra_error","root_cause":"server down","fixable_by_skill_update":false,"suggested_patch":null,"confidence":0.5,"extra":{"nested":"value"}}'
    result = Nightshift::CI::Judge.parse_verdict(raw)
    assert_equal Nightshift::VerdictName::InfraError, result.verdict
  end

  def test_parse_verdict_no_json
    raw = 'No JSON here, just text.'
    result = Nightshift::CI::Judge.parse_verdict(raw)
    assert_equal Nightshift::VerdictName::InfraError, result.verdict
    assert_includes result.root_cause, 'parse_error'
  end

  def test_parse_verdict_unknown_verdict
    raw = '{"verdict":"unknown_type","root_cause":"???"}'
    result = Nightshift::CI::Judge.parse_verdict(raw)
    assert_equal Nightshift::VerdictName::InfraError, result.verdict
    assert_includes result.root_cause, 'unknown_verdict'
  end

  def test_parse_verdict_clamps_confidence
    raw = '{"verdict":"skill_defect","root_cause":"x","confidence":1.5}'
    result = Nightshift::CI::Judge.parse_verdict(raw)
    assert_in_delta 1.0, result.confidence

    raw_neg = '{"verdict":"skill_defect","root_cause":"x","confidence":-0.5}'
    result_neg = Nightshift::CI::Judge.parse_verdict(raw_neg)
    assert_in_delta 0.0, result_neg.confidence
  end

  def test_parse_verdict_defaults_confidence_to_0_5
    raw = '{"verdict":"skill_defect","root_cause":"x"}'
    result = Nightshift::CI::Judge.parse_verdict(raw)
    assert_in_delta 0.5, result.confidence
  end

  def test_parse_verdict_truncates_root_cause
    long = 'x' * 1000
    raw = "{\"verdict\":\"item_hard\",\"root_cause\":\"#{long}\"}"
    result = Nightshift::CI::Judge.parse_verdict(raw)
    assert_equal 500, result.root_cause.length
  end

  # --- retryable? ---

  def test_retryable_skill_defect
    verdict = Nightshift::CI::Verdict.new(verdict: Nightshift::VerdictName::SkillDefect)
    assert Nightshift::CI::Judge.retryable?(verdict, 0)
    assert Nightshift::CI::Judge.retryable?(verdict, 2)
    refute Nightshift::CI::Judge.retryable?(verdict, 3)
  end

  def test_retryable_infra_error
    verdict = Nightshift::CI::Verdict.new(verdict: Nightshift::VerdictName::InfraError)
    assert Nightshift::CI::Judge.retryable?(verdict, 0)
    refute Nightshift::CI::Judge.retryable?(verdict, 3)
  end

  def test_not_retryable_item_hard
    verdict = Nightshift::CI::Verdict.new(verdict: Nightshift::VerdictName::ItemHard)
    refute Nightshift::CI::Judge.retryable?(verdict, 0)
  end

  def test_not_retryable_context_limit
    verdict = Nightshift::CI::Verdict.new(verdict: Nightshift::VerdictName::ContextLimit)
    refute Nightshift::CI::Judge.retryable?(verdict, 0)
  end

  # --- extract_digest ---

  def test_extract_digest_collects_errors
    log = Tempfile.new('judge-test.log')
    log.puts JSON.generate(type: 'user', message: { content: [
                             { 'is_error' => true, 'content' => 'Permission denied: Bash' }
                           ] })
    log.puts JSON.generate(type: 'assistant', message: { content: [
                             { 'type' => 'text', 'text' => "I'll try another approach" }
                           ] })
    log.close

    digest = Nightshift::CI::Judge.extract_digest(log.path)
    assert_includes digest, 'ERRORS (1)'
    assert_includes digest, 'Permission denied'
    assert_includes digest, 'LAST EVENTS'
    assert_includes digest, 'another approach'
  ensure
    log&.unlink
  end

  def test_extract_digest_keeps_last_15_events
    log = Tempfile.new('judge-test.log')
    20.times do |i|
      log.puts JSON.generate(type: 'assistant', message: { content: [
                               { 'type' => 'text', 'text' => "event #{i}" }
                             ] })
    end
    log.close

    digest = Nightshift::CI::Judge.extract_digest(log.path)
    refute_includes digest, 'event 0'
    refute_includes digest, 'event 4'
    assert_includes digest, 'event 5'
    assert_includes digest, 'event 19'
  ensure
    log&.unlink
  end

  def test_extract_digest_respects_max_bytes
    log = Tempfile.new('judge-test.log')
    100.times do |_i|
      log.puts JSON.generate(type: 'assistant', message: { content: [
                               { 'type' => 'text', 'text' => 'x' * 500 }
                             ] })
    end
    log.close

    digest = Nightshift::CI::Judge.extract_digest(log.path, max_bytes: 1000)
    assert digest.bytesize <= 1000
  ensure
    log&.unlink
  end

  def test_extract_digest_handles_malformed_lines
    log = Tempfile.new('judge-test.log')
    log.puts 'not json at all'
    log.puts ''
    log.puts JSON.generate(type: 'result', result: 'done')
    log.close

    digest = Nightshift::CI::Judge.extract_digest(log.path)
    assert_includes digest, 'done'
  ensure
    log&.unlink
  end

  # --- extract_event_text ---

  def test_extract_event_text_tool_use
    event = {
      'type' => 'assistant',
      'message' => { 'content' => [
        { 'type' => 'tool_use', 'name' => 'Bash', 'input' => { 'command' => 'git status' } }
      ] }
    }
    text = Nightshift::CI::Judge.extract_event_text(event)
    assert_includes text, 'tool_use: Bash(git status)'
  end

  def test_extract_event_text_result
    event = { 'type' => 'result', 'result' => 'Task completed successfully' }
    text = Nightshift::CI::Judge.extract_event_text(event)
    assert_equal 'Task completed successfully', text
  end

  # --- fallback_verdict ---

  def test_fallback_verdict
    result = Nightshift::CI::Judge.fallback_verdict(Nightshift::VerdictName::JudgeError, 'something broke')
    assert_equal Nightshift::VerdictName::InfraError, result.verdict
    assert_includes result.root_cause, 'judge_error'
    assert_includes result.root_cause, 'something broke'
    assert_equal 0.0, result.confidence
    assert_nil result.suggested_patch
  end

  # --- VERDICTS constant ---

  def test_verdicts_constant
    vn = Nightshift::VerdictName
    assert_equal [vn::SkillDefect, vn::ItemHard, vn::InfraError, vn::ContextLimit],
                 Nightshift::CI::Judge::VERDICTS
  end

  def test_max_retries
    assert_equal 3, Nightshift::CI::Judge::MAX_RETRIES
  end
end
