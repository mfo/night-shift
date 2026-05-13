require_relative "test_helper"

class CLIInspectTest < Minitest::Test
  def setup
    @db = Sequel.sqlite
    Sequel::Migrator.run(@db, "db/migrations")
    @store = Nightshift::Store.new(@db)
  end

  def test_inspect_shows_item_and_cycles
    item_id = add_item("haml-migration", "foo.haml", status: "skipped",
                        failure_reason: "autolearn_exhausted", retry_count: 3,
                        last_verdict: "skill_defect")
    add_cycle(item_id, attempt: 1, verdict: "skill_defect",
              root_cause: "server not started", confidence: 0.8,
              suggested_patch: "## Fix server")
    add_cycle(item_id, attempt: 2, verdict: "infra_error",
              root_cause: "overmind socket missing", confidence: 0.6)

    output = capture_inspect(item_id.to_s)

    assert_includes output, "##{item_id} [haml-migration] foo.haml"
    assert_includes output, "skipped (autolearn_exhausted)"
    assert_includes output, "Retries: 3/3"
    assert_includes output, "skill_defect"
    assert_includes output, "infra_error"
    assert_includes output, "server not started"
    assert_includes output, "suggested but NOT applied"
    assert_includes output, "confidence=0.8"
  end

  def test_inspect_shows_applied_patch
    item_id = add_item("i18n-hardcoded", "bar.rb", status: "skipped")
    add_cycle(item_id, attempt: 1, verdict: "skill_defect",
              suggested_patch: "## Patch", skill_patch_sha: "abc1234def5678")

    output = capture_inspect(item_id.to_s)

    assert_includes output, "applied (abc1234)"
  end

  def test_inspect_no_cycles
    item_id = add_item("haml-migration", "baz.haml", status: "pending")

    output = capture_inspect(item_id.to_s)

    assert_includes output, "No autolearn cycles."
  end

  def test_inspect_not_found
    error = assert_raises(SystemExit) { capture_inspect("999") }
    assert_equal 1, error.status
  end

  def test_backlog_retry_resets_item
    item_id = add_item("haml-migration", "foo.haml", status: "skipped",
                        failure_reason: "autolearn_exhausted", retry_count: 3,
                        last_verdict: "skill_defect")

    output = capture_backlog_retry(item_id.to_s)

    assert_includes output, "pending (retry_count reset)"

    updated = @db[:backlog_items].where(id: item_id).first
    assert_equal "pending", updated[:status]
    assert_equal 0, updated[:retry_count]
    assert_nil updated[:last_verdict]
  end

  def test_backlog_retry_rejects_running_item
    item_id = add_item("haml-migration", "foo.haml", status: "running")

    error = assert_raises(SystemExit) { capture_backlog_retry(item_id.to_s) }
    assert_equal 1, error.status
  end

  private

  def add_item(skill, item, status: "pending", **extras)
    now = Time.now.to_i
    @db[:backlog_items].insert(
      skill: skill, item: item, status: status,
      priority: 0, retry_count: extras.delete(:retry_count) || 0,
      last_verdict: extras.delete(:last_verdict),
      failure_reason: extras.delete(:failure_reason),
      created_at: now, updated_at: now
    )
  end

  def add_cycle(item_id, attempt:, verdict:, **extras)
    @db[:autolearn_cycles].insert(
      backlog_item_id: item_id, attempt: attempt, verdict: verdict,
      root_cause: extras[:root_cause], confidence: extras[:confidence],
      suggested_patch: extras[:suggested_patch],
      skill_patch_sha: extras[:skill_patch_sha],
      created_at: Time.now.to_i
    )
  end

  def with_cli_store
    original = Nightshift::CLI.instance_variable_get(:@store)
    Nightshift::CLI.instance_variable_set(:@store, @store)
    yield
  ensure
    Nightshift::CLI.instance_variable_set(:@store, original)
  end

  def capture_inspect(id)
    with_cli_store do
      capture_io { Nightshift::CLI.cmd_inspect([id]) }.first
    end
  end

  def capture_backlog_retry(id)
    with_cli_store do
      capture_io { Nightshift::CLI.cmd_backlog_retry([id]) }.first
    end
  end
end
