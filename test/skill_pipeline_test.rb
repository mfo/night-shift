# frozen_string_literal: true

require_relative 'test_helper'
require 'minitest/mock'
require 'open3'

class SkillPipelineTest < Minitest::Test
  def setup
    @db = Sequel.sqlite
    Sequel::Migrator.run(@db, 'db/migrations')
    @store = Nightshift::Core::Store.new(@db)
    @pipeline = Nightshift::Skills::Pipeline.new(store: @store)
  end

  # --- record_cycle (now on Store) ---

  def test_record_cycle_inserts_row
    backlog_item = add_backlog_item('haml-migration', 'a.haml')

    @store.record_cycle(backlog_item, verdict: Nightshift::VerdictName::Success, outcome: 'improved',
                                      log_path: '/tmp/test.log', turns: 42)

    cycle = @db[:autolearn_cycles].first
    assert_equal backlog_item.id, cycle[:backlog_item_id]
    assert_equal 1, cycle[:attempt]
    assert_equal 'success', cycle[:verdict]
    assert_equal 'improved', cycle[:outcome]
    assert_equal 42, cycle[:turns_used]
  end

  def test_record_cycle_with_skill_patch_sha
    backlog_item = add_backlog_item('haml-migration', 'a.haml')

    @store.record_cycle(backlog_item, verdict: Nightshift::VerdictName::SkillDefect,
                                      skill_patch_sha: 'abc1234')

    cycle = @db[:autolearn_cycles].first
    assert_equal 'abc1234', cycle[:skill_patch_sha]
  end

  def test_record_cycle_respects_retry_count
    backlog_item = add_backlog_item('haml-migration', 'a.haml')
    @db[:backlog_items].where(id: backlog_item.id).update(retry_count: 2)
    row = @db[:backlog_items].where(id: backlog_item.id).first
    backlog_item = Nightshift::Core::BacklogItem.from_row(row)

    @store.record_cycle(backlog_item, verdict: Nightshift::VerdictName::InfraError)

    cycle = @db[:autolearn_cycles].first
    assert_equal 3, cycle[:attempt]
  end

  # --- apply_patch ---

  def test_apply_patch_creates_pitfall_section_and_returns_sha
    dir = Dir.mktmpdir
    skill_dir = File.join(dir, '.claude', 'skills', 'test-skill')
    FileUtils.mkdir_p(skill_dir)
    patterns_path = File.join(skill_dir, 'patterns.md')
    File.write(patterns_path, "# Patterns\n\nSome content.\n")

    sha = nil
    @pipeline.stub(:nightshift_dir, dir) do
      @pipeline.stub(:system, true) do
        Open3.stub(:capture2, ["abc1234def\n", nil]) do
          sha = @pipeline.apply_patch('test-skill', 'Watch out for X')
        end
      end
    end

    content = File.read(patterns_path)
    assert_includes content, '## Auto-discovered pitfalls'
    assert_includes content, '### AL-1'
    assert_includes content, 'Watch out for X'
    assert_equal 'abc1234def', sha
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  def test_apply_patch_creates_patterns_md_when_missing
    dir = Dir.mktmpdir
    skill_dir = File.join(dir, '.claude', 'skills', 'new-skill')
    FileUtils.mkdir_p(skill_dir)

    sha = nil
    @pipeline.stub(:nightshift_dir, dir) do
      @pipeline.stub(:system, true) do
        Open3.stub(:capture2, ["abc1234def\n", nil]) do
          sha = @pipeline.apply_patch('new-skill', 'Watch out for Y')
        end
      end
    end

    patterns_path = File.join(skill_dir, 'patterns.md')
    assert File.exist?(patterns_path), 'patterns.md should have been created'
    content = File.read(patterns_path)
    assert_includes content, '# Patterns new-skill'
    assert_includes content, '## Auto-discovered pitfalls'
    assert_includes content, '### AL-1'
    assert_includes content, 'Watch out for Y'
    assert_equal 'abc1234def', sha
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  def test_apply_patch_returns_nil_when_git_add_fails
    dir = Dir.mktmpdir
    skill_dir = File.join(dir, '.claude', 'skills', 'test-skill')
    FileUtils.mkdir_p(skill_dir)
    patterns_path = File.join(skill_dir, 'patterns.md')
    File.write(patterns_path, "# Patterns\n\nSome content.\n")

    result = nil
    @pipeline.stub(:nightshift_dir, dir) do
      @pipeline.stub(:system, false) do
        result = @pipeline.apply_patch('test-skill', 'Watch out for X')
      end
    end

    assert_nil result
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  def test_apply_patch_respects_5_cap
    dir = Dir.mktmpdir
    skill_dir = File.join(dir, '.claude', 'skills', 'test-skill')
    FileUtils.mkdir_p(skill_dir)
    patterns_path = File.join(skill_dir, 'patterns.md')
    content = "# Patterns\n\n## Auto-discovered pitfalls\n\n"
    5.times { |i| content += "### AL-#{i + 1} (2026-01-01)\n\npitfall #{i}\n\n" }
    File.write(patterns_path, content)

    @pipeline.stub(:nightshift_dir, dir) do
      @pipeline.apply_patch('test-skill', 'Should not be added')
    end

    content = File.read(patterns_path)
    refute_includes content, 'AL-6'
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  # --- handle_failure ---

  def test_handle_failure_retryable_resets_to_pending
    backlog_item = add_backlog_item('haml-migration', 'a.haml', status: 'running')
    result = Nightshift::Skills::RunnerResult.new(
      success: false, failure_reason: 'claude_error',
      log_path: '/tmp/test.log', turns_used: 10, files_changed: 0
    )

    retryable_verdict = Nightshift::CI::Verdict.new(
      verdict: Nightshift::VerdictName::SkillDefect, root_cause: 'missing instruction',
      fixable_by_skill_update: true, suggested_patch: nil, confidence: 0.8
    )

    Nightshift::CI::Judge.stub(:evaluate, retryable_verdict) do
      Nightshift::Integrations::Worktree.stub(:cleanup, nil) do
        @pipeline.handle_failure(backlog_item, result)
      end
    end

    updated = @db[:backlog_items].where(id: backlog_item.id).first
    assert_equal 'pending', updated[:status]
    assert_equal 1, updated[:retry_count]
    assert_equal 'skill_defect', updated[:last_verdict]
  end

  def test_handle_failure_non_retryable_skips_and_cleans_worktree
    backlog_item = add_backlog_item('haml-migration', 'a.haml', status: 'running')
    result = Nightshift::Skills::RunnerResult.new(
      success: false, failure_reason: 'claude_error',
      log_path: '/tmp/test.log', turns_used: 10, files_changed: 0
    )

    hard_verdict = Nightshift::CI::Verdict.new(
      verdict: Nightshift::VerdictName::ItemHard, root_cause: 'too complex',
      fixable_by_skill_update: false, suggested_patch: nil, confidence: 0.9
    )

    cleaned_branch = nil
    Nightshift::CI::Judge.stub(:evaluate, hard_verdict) do
      Nightshift::Integrations::Worktree.stub(:cleanup, ->(b) { cleaned_branch = b }) do
        @pipeline.handle_failure(backlog_item, result)
      end
    end

    updated = @db[:backlog_items].where(id: backlog_item.id).first
    assert_equal 'skipped', updated[:status]
    assert_equal 'item_hard', updated[:failure_reason]
    assert_nil updated[:branch], 'branch should be cleared on skip'
    assert_equal 'auto/haml-migration/test', cleaned_branch, 'worktree should be cleaned up'
  end

  def test_handle_failure_exhausted_retries_skips
    backlog_item = add_backlog_item('haml-migration', 'a.haml', status: 'running')
    @db[:backlog_items].where(id: backlog_item.id).update(retry_count: 3)
    row = @db[:backlog_items].where(id: backlog_item.id).first
    backlog_item = Nightshift::Core::BacklogItem.from_row(row)

    result = Nightshift::Skills::RunnerResult.new(
      success: false, failure_reason: 'claude_error',
      log_path: '/tmp/test.log', turns_used: 10, files_changed: 0
    )

    retryable_verdict = Nightshift::CI::Verdict.new(
      verdict: Nightshift::VerdictName::SkillDefect, root_cause: 'still broken',
      fixable_by_skill_update: true, suggested_patch: nil, confidence: 0.8
    )

    Nightshift::CI::Judge.stub(:evaluate, retryable_verdict) do
      Nightshift::Integrations::Worktree.stub(:cleanup, nil) do
        @pipeline.handle_failure(backlog_item, result)
      end
    end

    updated = @db[:backlog_items].where(id: backlog_item.id).first
    assert_equal 'skipped', updated[:status]
    assert_equal 'autolearn_exhausted', updated[:failure_reason]
  end

  def test_handle_failure_records_cycle
    backlog_item = add_backlog_item('haml-migration', 'a.haml', status: 'running')
    result = Nightshift::Skills::RunnerResult.new(
      success: false, failure_reason: 'no_diff',
      log_path: '/tmp/test.log', turns_used: 5, files_changed: 0
    )

    verdict = Nightshift::CI::Verdict.new(
      verdict: Nightshift::VerdictName::ItemHard, root_cause: 'complex file',
      fixable_by_skill_update: false, suggested_patch: nil, confidence: 0.7
    )

    Nightshift::CI::Judge.stub(:evaluate, verdict) do
      Nightshift::Integrations::Worktree.stub(:cleanup, nil) do
        @pipeline.handle_failure(backlog_item, result)
      end
    end

    cycle = @db[:autolearn_cycles].first
    assert_equal 'item_hard', cycle[:verdict]
    assert_equal 'complex file', cycle[:root_cause]
    assert_equal 5, cycle[:turns_used]
  end

  def test_handle_failure_rate_limited_skips_judge_and_backs_off
    backlog_item = add_backlog_item('haml-migration', 'a.haml', status: 'running')
    result = Nightshift::Skills::RunnerResult.new(
      success: false, failure_reason: 'rate_limited',
      log_path: '/tmp/test.log', turns_used: 2, files_changed: 0
    )

    Nightshift::Integrations::Worktree.stub(:cleanup, nil) do
      @pipeline.handle_failure(backlog_item, result)
    end

    updated = @db[:backlog_items].where(id: backlog_item.id).first
    assert_equal 'pending', updated[:status]
    assert_nil updated[:branch]
    assert updated[:retry_after] > Time.now.to_i,
           'retry_after should be in the future'

    cycle = @db[:autolearn_cycles].first
    assert_equal 'rate_limited', cycle[:verdict]
  end

  def test_handle_failure_infra_error_creates_suggestion
    backlog_item = add_backlog_item('haml-migration', 'a.haml', status: 'running')
    result = Nightshift::Skills::RunnerResult.new(
      success: false, failure_reason: 'claude_error',
      log_path: '/tmp/test.log', turns_used: 3, files_changed: 0
    )

    verdict = Nightshift::CI::Verdict.new(
      verdict: Nightshift::VerdictName::InfraError, root_cause: 'server not started',
      fixable_by_skill_update: false, suggested_patch: nil, confidence: 0.6
    )

    Nightshift::CI::Judge.stub(:evaluate, verdict) do
      Nightshift::Integrations::Worktree.stub(:cleanup, nil) do
        @pipeline.handle_failure(backlog_item, result)
      end
    end

    suggestion = @db[:infra_suggestions].first
    assert_equal 'server not started', suggestion[:description]
    assert_equal 'judge', suggestion[:source]
  end

  # --- execute_batch ---

  def test_execute_batch_all_success
    bi1 = add_backlog_item('i18n', 'a.rb', batch_id: 'batch123')
    bi2 = add_backlog_item('i18n', 'b.rb', batch_id: 'batch123')

    success_result = Nightshift::Skills::RunnerResult.new(
      success: true, failure_reason: nil,
      log_path: '/tmp/test.log', turns_used: 5, files_changed: 1
    )

    desc_path = nil
    Nightshift::Integrations::Worktree.stub(:path_for_branch, '/tmp/wt') do
      Nightshift::Skills::Runner.stub(:run, success_result) do
        # Stub pr-description.md existence and content
        @pipeline.stub(:system, true) do
          File.stub(:exist?, ->(p) { desc_path = p; true }) do
            File.stub(:read, "---\ntitle: \"batch PR\"\n---\nBody here") do
              Open3.stub(:capture2, ["https://github.com/org/repo/pull/42\n", nil]) do
                @pipeline.execute_batch([bi1, bi2])
              end
            end
          end
        end
      end
    end

    # Both items should be pr_open
    assert_equal 'pr_open', @db[:backlog_items].where(id: bi1.id).first[:status]
    assert_equal 'pr_open', @db[:backlog_items].where(id: bi2.id).first[:status]

    # Both share same PR number
    assert_equal 42, @db[:backlog_items].where(id: bi1.id).first[:pr_number]
    assert_equal 42, @db[:backlog_items].where(id: bi2.id).first[:pr_number]

    # 2 success cycles recorded
    cycles = @db[:autolearn_cycles].where(verdict: 'success').all
    assert_equal 2, cycles.size
  end

  def test_execute_batch_partial_failure
    bi1 = add_backlog_item('i18n', 'a.rb', batch_id: 'batch456')
    bi2 = add_backlog_item('i18n', 'b.rb', batch_id: 'batch456')

    success_result = Nightshift::Skills::RunnerResult.new(
      success: true, failure_reason: nil,
      log_path: '/tmp/test.log', turns_used: 5, files_changed: 1
    )
    fail_result = Nightshift::Skills::RunnerResult.new(
      success: false, failure_reason: 'claude_error',
      log_path: '/tmp/test.log', turns_used: 3, files_changed: 0
    )

    call_count = 0
    runner_stub = lambda do |_skill, item:, worktree_path:, context: nil|
      call_count += 1
      call_count == 1 ? success_result : fail_result
    end

    hard_verdict = Nightshift::CI::Verdict.new(
      verdict: Nightshift::VerdictName::ItemHard, root_cause: 'too complex',
      fixable_by_skill_update: false, suggested_patch: nil, confidence: 0.9
    )

    Nightshift::Integrations::Worktree.stub(:path_for_branch, '/tmp/wt') do
      Nightshift::Skills::Runner.stub(:run, runner_stub) do
        Nightshift::CI::Judge.stub(:evaluate, hard_verdict) do
          Nightshift::Integrations::Worktree.stub(:cleanup, nil) do
            @pipeline.stub(:system, true) do
              File.stub(:exist?, true) do
                File.stub(:read, "---\ntitle: \"partial batch\"\n---\nBody") do
                  Open3.stub(:capture2, ["https://github.com/org/repo/pull/99\n", nil]) do
                    @pipeline.execute_batch([bi1, bi2])
                  end
                end
              end
            end
          end
        end
      end
    end

    # First item succeeded → pr_open
    assert_equal 'pr_open', @db[:backlog_items].where(id: bi1.id).first[:status]
    assert_equal 99, @db[:backlog_items].where(id: bi1.id).first[:pr_number]

    # Second item failed → skipped (item_hard)
    assert_equal 'skipped', @db[:backlog_items].where(id: bi2.id).first[:status]
  end

  def test_execute_batch_no_worktree
    bi1 = add_backlog_item('i18n', 'a.rb', batch_id: 'batchXYZ')
    bi2 = add_backlog_item('i18n', 'b.rb', batch_id: 'batchXYZ')

    Nightshift::Integrations::Worktree.stub(:path_for_branch, nil) do
      @pipeline.execute_batch([bi1, bi2])
    end

    assert_equal 'failed', @db[:backlog_items].where(id: bi1.id).first[:status]
    assert_equal 'failed', @db[:backlog_items].where(id: bi2.id).first[:status]
  end

  def test_execute_batch_all_fail
    bi1 = add_backlog_item('i18n', 'a.rb', batch_id: 'batchFAIL')

    fail_result = Nightshift::Skills::RunnerResult.new(
      success: false, failure_reason: 'no_diff',
      log_path: '/tmp/test.log', turns_used: 5, files_changed: 0
    )

    hard_verdict = Nightshift::CI::Verdict.new(
      verdict: Nightshift::VerdictName::ItemHard, root_cause: 'too complex',
      fixable_by_skill_update: false, suggested_patch: nil, confidence: 0.9
    )

    Nightshift::Integrations::Worktree.stub(:path_for_branch, '/tmp/wt') do
      Nightshift::Skills::Runner.stub(:run, fail_result) do
        Nightshift::CI::Judge.stub(:evaluate, hard_verdict) do
          Nightshift::Integrations::Worktree.stub(:cleanup, nil) do
            @pipeline.execute_batch([bi1])
          end
        end
      end
    end

    assert_equal 'skipped', @db[:backlog_items].where(id: bi1.id).first[:status]
  end

  # --- confidence threshold ---

  def test_handle_failure_low_confidence_skips_patch
    backlog_item = add_backlog_item('haml-migration', 'a.haml', status: 'running')
    result = Nightshift::Skills::RunnerResult.new(
      success: false, failure_reason: 'claude_error',
      log_path: '/tmp/test.log', turns_used: 10, files_changed: 0
    )

    low_conf_verdict = Nightshift::CI::Verdict.new(
      verdict: Nightshift::VerdictName::SkillDefect, root_cause: 'missing instruction',
      fixable_by_skill_update: true, suggested_patch: 'Add this rule', confidence: 0.6
    )

    patch_called = false
    Nightshift::CI::Judge.stub(:evaluate, low_conf_verdict) do
      Nightshift::Integrations::Worktree.stub(:cleanup, nil) do
        @pipeline.stub(:apply_patch, ->(*) { patch_called = true; 'abc123' }) do
          @pipeline.handle_failure(backlog_item, result)
        end
      end
    end

    refute patch_called, 'apply_patch should NOT be called at confidence 0.6'

    # Item should still be reset to pending (retryable)
    updated = @db[:backlog_items].where(id: backlog_item.id).first
    assert_equal 'pending', updated[:status]
  end

  private

  def add_backlog_item(skill, item, status: 'running', batch_id: nil)
    now = Time.now.to_i
    id = @db[:backlog_items].insert(
      skill: skill, item: item, status: status,
      branch: "auto/#{skill}/test", priority: 0,
      retry_count: 0, batch_id: batch_id,
      created_at: now, updated_at: now
    )
    row = @db[:backlog_items].where(id: id).first
    Nightshift::Core::BacklogItem.from_row(row)
  end
end
