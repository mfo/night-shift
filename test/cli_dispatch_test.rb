require_relative "test_helper"

class CLIDispatchTest < Minitest::Test
  def setup
    @db = Sequel.sqlite
    Sequel::Migrator.run(@db, "db/migrations")
    @store = Nightshift::Core::Store.new(@db)
  end

  # --- Thor command registration ---

  def test_all_expected_commands_registered
    expected = %w[attach watch diagnose autofix brief merge open close
                  auto skill_run reset inspect_item autolearn_status autolearn_report]
    expected.each do |cmd|
      assert Nightshift::CLI.all_commands.key?(cmd), "Missing command: #{cmd}"
    end
  end

  def test_backlog_subcommand_registered
    assert_includes Nightshift::CLI.subcommands, "backlog"
  end

  def test_hyphenated_commands_mapped
    maps = Nightshift::CLI.all_commands
    assert maps.key?("skill_run"), "skill-run should map to skill_run"
    assert maps.key?("autolearn_status"), "autolearn-status should map to autolearn_status"
    assert maps.key?("autolearn_report"), "autolearn-report should map to autolearn_report"
    assert maps.key?("inspect_item"), "inspect should map to inspect_item"
  end

  # --- Dispatch routing ---

  def test_dispatch_unknown_command_exits
    assert_raises(SystemExit) do
      capture_io { Nightshift::CLI.start(["unknown-command"]) }
    end
  end

  def test_dispatch_no_command_shows_help
    output = capture_io { Nightshift::CLI.start([]) }.first
    assert_includes output, "Commands:"
  end

  # --- Backlog subcommands ---

  def test_backlog_add_creates_item
    with_cli_store do
      capture_io { Nightshift::CLI.start(["backlog", "add", "haml-migration", "foo.haml"]) }
    end
    assert_equal 1, @db[:backlog_items].count
    assert_equal "foo.haml", @db[:backlog_items].first[:item]
  end

  def test_backlog_add_missing_args
    assert_raises(SystemExit) do
      with_cli_store do
        capture_io { Nightshift::CLI.start(["backlog", "add"]) }
      end
    end
  end

  def test_backlog_list_shows_items
    @store.add_backlog("haml-migration", "a.haml")
    @store.add_backlog("haml-migration", "b.haml")

    output = with_cli_store do
      capture_io { Nightshift::CLI.start(["backlog", "list"]) }.first
    end
    assert_includes output, "a.haml"
    assert_includes output, "b.haml"
    assert_includes output, "2 items"
  end

  def test_backlog_list_filters_by_skill
    @store.add_backlog("haml-migration", "a.haml")
    @store.add_backlog("test-optimization", "b_spec.rb")

    output = with_cli_store do
      capture_io { Nightshift::CLI.start(["backlog", "list", "haml-migration"]) }.first
    end
    assert_includes output, "a.haml"
    refute_includes output, "b_spec.rb"
  end

  def test_backlog_skip_requires_failed_status
    @store.add_backlog("haml-migration", "a.haml")
    item = @store.claim_next("haml-migration")

    assert_raises(SystemExit) do
      with_cli_store do
        capture_io { Nightshift::CLI.start(["backlog", "skip", item[:id].to_s]) }
      end
    end
  end

  def test_backlog_skip_works_on_failed
    @store.add_backlog("haml-migration", "a.haml")
    item = @store.claim_next("haml-migration")
    @store.update_backlog_status(item[:id], "failed", failure_reason: "test")

    with_cli_store do
      capture_io { Nightshift::CLI.start(["backlog", "skip", item[:id].to_s]) }
    end
    assert_equal "skipped", @db[:backlog_items].first[:status]
  end

  def test_backlog_dispatch_unknown_subcommand
    assert_raises(SystemExit) do
      with_cli_store do
        capture_io { Nightshift::CLI.start(["backlog", "unknown"]) }
      end
    end
  end

  # --- Merge / Diagnose / Autofix ---

  def test_merge_requires_pr_number
    assert_raises(SystemExit) do
      capture_io { Nightshift::CLI.start(["merge"]) }
    end
  end

  def test_diagnose_requires_pr_number
    assert_raises(SystemExit) do
      capture_io { Nightshift::CLI.start(["diagnose"]) }
    end
  end

  def test_autofix_requires_pr_number
    assert_raises(SystemExit) do
      capture_io { Nightshift::CLI.start(["autofix"]) }
    end
  end

  # --- Autolearn commands ---

  def test_autolearn_status_runs
    output = with_cli_store do
      capture_io { Nightshift::CLI.start(["autolearn-status"]) }.first
    end
    assert_includes output, "autolearn status"
  end

  def test_autolearn_report_runs
    output = with_cli_store do
      capture_io { Nightshift::CLI.start(["autolearn-report"]) }.first
    end
    refute_nil output
  end

  private

  def with_cli_store(&block)
    original = Nightshift::CLI.instance_variable_get(:@store)
    Nightshift::CLI.store = @store
    result = yield
    result
  ensure
    Nightshift::CLI.instance_variable_set(:@store, original)
  end
end
