require_relative "test_helper"
require "minitest/mock"
require "open3"

class SkillPipelineTest < Minitest::Test
  def setup
    @db = Sequel.sqlite
    Sequel::Migrator.run(@db, "db/migrations")
    @store = Nightshift::Store.new(@db)
    @pipeline = Nightshift::SkillPipeline.new(store: @store)
  end

  # --- record_cycle ---

  def test_record_cycle_inserts_row
    item = add_backlog_item("haml-migration", "a.haml")

    @pipeline.record_cycle(item, verdict: "success", outcome: "improved",
                           log_path: "/tmp/test.log", turns: 42)

    cycle = @db[:autolearn_cycles].first
    assert_equal item[:id], cycle[:backlog_item_id]
    assert_equal 1, cycle[:attempt]
    assert_equal "success", cycle[:verdict]
    assert_equal "improved", cycle[:outcome]
    assert_equal 42, cycle[:turns_used]
  end

  def test_record_cycle_with_skill_patch_sha
    item = add_backlog_item("haml-migration", "a.haml")

    @pipeline.record_cycle(item, verdict: "skill_defect",
                           skill_patch_sha: "abc1234")

    cycle = @db[:autolearn_cycles].first
    assert_equal "abc1234", cycle[:skill_patch_sha]
  end

  def test_record_cycle_respects_retry_count
    item = add_backlog_item("haml-migration", "a.haml")
    @db[:backlog_items].where(id: item[:id]).update(retry_count: 2)
    item = @db[:backlog_items].where(id: item[:id]).first

    @pipeline.record_cycle(item, verdict: "infra_error")

    cycle = @db[:autolearn_cycles].first
    assert_equal 3, cycle[:attempt]
  end

  # --- apply_patch ---

  def test_apply_patch_creates_pitfall_section
    dir = Dir.mktmpdir
    skill_dir = File.join(dir, ".claude", "skills", "test-skill")
    FileUtils.mkdir_p(skill_dir)
    patterns_path = File.join(skill_dir, "patterns.md")
    File.write(patterns_path, "# Patterns\n\nSome content.\n")

    @pipeline.stub(:nightshift_dir, dir) do
      @pipeline.stub(:system, true) do
        @pipeline.apply_patch("test-skill", "Watch out for X")
      end
    end

    content = File.read(patterns_path)
    assert_includes content, "## Auto-discovered pitfalls"
    assert_includes content, "### AL-1"
    assert_includes content, "Watch out for X"
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  def test_apply_patch_respects_5_cap
    dir = Dir.mktmpdir
    skill_dir = File.join(dir, ".claude", "skills", "test-skill")
    FileUtils.mkdir_p(skill_dir)
    patterns_path = File.join(skill_dir, "patterns.md")
    content = "# Patterns\n\n## Auto-discovered pitfalls\n\n"
    5.times { |i| content += "### AL-#{i + 1} (2026-01-01)\n\npitfall #{i}\n\n" }
    File.write(patterns_path, content)

    @pipeline.stub(:nightshift_dir, dir) do
      @pipeline.apply_patch("test-skill", "Should not be added")
    end

    content = File.read(patterns_path)
    refute_includes content, "AL-6"
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  # --- handle_failure ---

  def test_handle_failure_retryable_resets_to_pending
    item = add_backlog_item("haml-migration", "a.haml", status: "running")
    result = { failure_reason: "claude_error", log_path: "/tmp/test.log", turns_used: 10 }

    retryable_verdict = {
      verdict: "skill_defect", root_cause: "missing instruction",
      fixable_by_skill_update: true, suggested_patch: nil, confidence: 0.8
    }

    Nightshift::Judge.stub(:evaluate, retryable_verdict) do
      Nightshift::Worktree.stub(:cleanup, nil) do
        Open3.stub(:capture2, ["auto/haml-migration/a\n", nil]) do
          @pipeline.handle_failure("haml-migration", "a.haml", "/tmp/wt", item, result)
        end
      end
    end

    updated = @db[:backlog_items].where(id: item[:id]).first
    assert_equal "pending", updated[:status]
    assert_equal 1, updated[:retry_count]
    assert_equal "skill_defect", updated[:last_verdict]
  end

  def test_handle_failure_non_retryable_skips
    item = add_backlog_item("haml-migration", "a.haml", status: "running")
    result = { failure_reason: "claude_error", log_path: "/tmp/test.log", turns_used: 10 }

    hard_verdict = {
      verdict: "item_hard", root_cause: "too complex",
      fixable_by_skill_update: false, suggested_patch: nil, confidence: 0.9
    }

    Nightshift::Judge.stub(:evaluate, hard_verdict) do
      @pipeline.handle_failure("haml-migration", "a.haml", "/tmp/wt", item, result)
    end

    updated = @db[:backlog_items].where(id: item[:id]).first
    assert_equal "skipped", updated[:status]
    assert_equal "item_hard", updated[:failure_reason]
  end

  def test_handle_failure_exhausted_retries_skips
    item = add_backlog_item("haml-migration", "a.haml", status: "running")
    @db[:backlog_items].where(id: item[:id]).update(retry_count: 3)
    item = @db[:backlog_items].where(id: item[:id]).first

    result = { failure_reason: "claude_error", log_path: "/tmp/test.log", turns_used: 10 }

    retryable_verdict = {
      verdict: "skill_defect", root_cause: "still broken",
      fixable_by_skill_update: true, suggested_patch: nil, confidence: 0.8
    }

    Nightshift::Judge.stub(:evaluate, retryable_verdict) do
      @pipeline.handle_failure("haml-migration", "a.haml", "/tmp/wt", item, result)
    end

    updated = @db[:backlog_items].where(id: item[:id]).first
    assert_equal "skipped", updated[:status]
    assert_equal "autolearn_exhausted", updated[:failure_reason]
  end

  def test_handle_failure_records_cycle
    item = add_backlog_item("haml-migration", "a.haml", status: "running")
    result = { failure_reason: "no_diff", log_path: "/tmp/test.log", turns_used: 5 }

    verdict = {
      verdict: "item_hard", root_cause: "complex file",
      fixable_by_skill_update: false, suggested_patch: nil, confidence: 0.7
    }

    Nightshift::Judge.stub(:evaluate, verdict) do
      @pipeline.handle_failure("haml-migration", "a.haml", "/tmp/wt", item, result)
    end

    cycle = @db[:autolearn_cycles].first
    assert_equal "item_hard", cycle[:verdict]
    assert_equal "complex file", cycle[:root_cause]
    assert_equal 5, cycle[:turns_used]
  end

  def test_handle_failure_infra_error_creates_suggestion
    item = add_backlog_item("haml-migration", "a.haml", status: "running")
    result = { failure_reason: "claude_error", log_path: "/tmp/test.log", turns_used: 3 }

    verdict = {
      verdict: "infra_error", root_cause: "server not started",
      fixable_by_skill_update: false, suggested_patch: nil, confidence: 0.6
    }

    Nightshift::Judge.stub(:evaluate, verdict) do
      Nightshift::Worktree.stub(:cleanup, nil) do
        Open3.stub(:capture2, ["auto/haml-migration/a\n", nil]) do
          @pipeline.handle_failure("haml-migration", "a.haml", "/tmp/wt", item, result)
        end
      end
    end

    suggestion = @db[:infra_suggestions].first
    assert_equal "server not started", suggestion[:description]
    assert_equal "judge", suggestion[:source]
  end

  private

  def add_backlog_item(skill, item, status: "running")
    now = Time.now.to_i
    id = @db[:backlog_items].insert(
      skill: skill, item: item, status: status,
      branch: "auto/#{skill}/test", priority: 0,
      retry_count: 0, created_at: now, updated_at: now
    )
    @db[:backlog_items].where(id: id).first
  end
end
