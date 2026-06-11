require_relative "test_helper"

class CLIDispatchTest < Minitest::Test
  def setup
    @db = Sequel.sqlite
    Sequel::Migrator.run(@db, "db/migrations")
    @store = Nightshift::Core::Store.new(@db)
  end

  # --- COMMANDS constant ---

  def test_commands_list_contains_all_expected
    expected = %w[attach watch diagnose autofix brief merge open close
                  backlog auto skill-run reset inspect autolearn-status autolearn-report]
    expected.each do |cmd|
      assert_includes Nightshift::CLI::COMMANDS, cmd, "Missing command: #{cmd}"
    end
  end

  # --- Dispatch routing ---
  # Verify each command routes to the right method by checking it doesn't crash
  # on missing args (abort with usage) or runs successfully with mocked deps.

  def test_dispatch_unknown_command_shows_usage
    assert_raises(SystemExit) do
      capture_io { Nightshift::CLI.run(["unknown-command"]) }
    end
  end

  def test_dispatch_no_command_shows_usage
    assert_raises(SystemExit) do
      capture_io { Nightshift::CLI.run([]) }
    end
  end

  # --- Backlog subcommands ---

  def test_backlog_add_creates_item
    with_cli_store do
      capture_io { Nightshift::CLI.cmd_backlog_add(["haml-migration", "foo.haml"]) }
    end
    assert_equal 1, @db[:backlog_items].count
    assert_equal "foo.haml", @db[:backlog_items].first[:item]
  end

  def test_backlog_add_missing_args
    assert_raises(SystemExit) do
      with_cli_store { Nightshift::CLI.cmd_backlog_add([]) }
    end
  end

  def test_backlog_list_shows_items
    @store.add_backlog("haml-migration", "a.haml")
    @store.add_backlog("haml-migration", "b.haml")

    output = with_cli_store do
      capture_io { Nightshift::CLI.cmd_backlog_list([]) }.first
    end
    assert_includes output, "a.haml"
    assert_includes output, "b.haml"
    assert_includes output, "2 items"
  end

  def test_backlog_list_filters_by_skill
    @store.add_backlog("haml-migration", "a.haml")
    @store.add_backlog("test-optimization", "b_spec.rb")

    output = with_cli_store do
      capture_io { Nightshift::CLI.cmd_backlog_list(["haml-migration"]) }.first
    end
    assert_includes output, "a.haml"
    refute_includes output, "b_spec.rb"
  end

  def test_backlog_skip_requires_failed_status
    @store.add_backlog("haml-migration", "a.haml")
    item = @store.claim_next("haml-migration")

    assert_raises(SystemExit) do
      with_cli_store { Nightshift::CLI.cmd_backlog_skip([item[:id].to_s]) }
    end
  end

  def test_backlog_skip_works_on_failed
    @store.add_backlog("haml-migration", "a.haml")
    item = @store.claim_next("haml-migration")
    @store.update_backlog_status(item[:id], "failed", failure_reason: "test")

    with_cli_store do
      capture_io { Nightshift::CLI.cmd_backlog_skip([item[:id].to_s]) }
    end
    assert_equal "skipped", @db[:backlog_items].first[:status]
  end

  def test_backlog_dispatch_unknown_subcommand
    assert_raises(SystemExit) do
      with_cli_store { Nightshift::CLI.cmd_backlog(["unknown"]) }
    end
  end

  # --- Merge / Diagnose / Autofix ---

  def test_merge_requires_pr_number
    assert_raises(SystemExit) do
      Nightshift::CLI.cmd_merge([])
    end
  end

  def test_diagnose_requires_pr_number
    assert_raises(SystemExit) do
      Nightshift::CLI.cmd_diagnose([])
    end
  end

  def test_autofix_requires_pr_number
    assert_raises(SystemExit) do
      Nightshift::CLI.cmd_autofix([])
    end
  end

  # --- Autolearn commands ---

  def test_autolearn_status_runs
    output = with_cli_store do
      capture_io { Nightshift::CLI.cmd_autolearn_status([]) }.first
    end
    assert_includes output, "autolearn status"
  end

  def test_autolearn_report_runs
    output = with_cli_store do
      capture_io { Nightshift::CLI.cmd_autolearn_report([]) }.first
    end
    # Could be empty or "aucun cycle"
    refute_nil output
  end

  private

  def with_cli_store(&block)
    original = Nightshift::CLI.instance_variable_get(:@store)
    Nightshift::CLI.instance_variable_set(:@store, @store)
    result = yield
    result
  ensure
    Nightshift::CLI.instance_variable_set(:@store, original)
  end
end
