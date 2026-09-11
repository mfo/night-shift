# frozen_string_literal: true

require_relative 'test_helper'

class RunnerConfigTest < Minitest::Test
  def setup
    @original_config = Nightshift.config
  end

  def teardown
    Nightshift.config = @original_config
  end

  def test_default_runner_is_claude
    assert_equal 'claude', Nightshift.runner
  end

  def test_runner_for_skill_returns_default_backend_harness
    assert_equal 'claude', Nightshift.runner_for('haml-migration')
  end

  def test_backend_for_returns_llm_backend_struct
    backend = Nightshift.backend_for('haml-migration')
    assert_instance_of Nightshift::Core::LLMBackend, backend
  end

  def test_backend_for_skill_with_override
    config = build_config(
      backends: {
        'local' => Nightshift::Core::LLMBackend.new(name: 'local', harness: 'claude-ds4', concurrency: 1),
        'frontier' => Nightshift::Core::LLMBackend.new(name: 'frontier', harness: 'claude', concurrency: 4)
      },
      default_backend: 'local',
      skills: {
        'haml-migration' => {},
        'bugfix' => { backend: 'frontier' }
      }
    )
    Nightshift.config = config

    assert_equal 'claude-ds4', Nightshift.runner_for('haml-migration')
    assert_equal 'claude', Nightshift.runner_for('bugfix')
    assert_equal 1, Nightshift.backend_for('haml-migration').concurrency
    assert_equal 4, Nightshift.backend_for('bugfix').concurrency
  end

  def test_backend_for_unknown_skill_returns_default
    backend = Nightshift.backend_for('nonexistent-skill')
    assert_equal 'claude', backend.harness
  end

  # --- Plage horaire (schedule) ---

  def test_schedule_switches_default_backend_at_night
    Nightshift.config = night_config

    assert_equal 'claude', Nightshift.runner_for('haml-migration', now: at(22))
    assert_equal 'claude', Nightshift.runner_for('haml-migration', now: at(2))
    assert_equal 'claude', Nightshift.runner_for('haml-migration', now: at(20, 0))
    assert_equal 'claude', Nightshift.runner_for('haml-migration', now: at(3, 59))
  end

  def test_schedule_falls_back_to_default_backend_during_the_day
    Nightshift.config = night_config

    assert_equal 'claude-ds4', Nightshift.runner_for('haml-migration', now: at(4, 0))
    assert_equal 'claude-ds4', Nightshift.runner_for('haml-migration', now: at(11))
    assert_equal 'claude-ds4', Nightshift.runner_for('haml-migration', now: at(19, 59))
  end

  def test_night_backend_carries_its_own_concurrency
    Nightshift.config = night_config

    assert_equal 5, Nightshift.backend_for('haml-migration', now: at(22)).concurrency
    assert_equal 1, Nightshift.backend_for('haml-migration', now: at(11)).concurrency
  end

  def test_skill_pinned_backend_wins_over_schedule
    Nightshift.config = night_config(skills: { 'haml-migration' => { backend: 'local' } })

    assert_equal 'claude-ds4', Nightshift.runner_for('haml-migration', now: at(22))
  end

  def test_next_switch_at_returns_upcoming_boundary
    Nightshift.config = night_config

    assert_equal at(20), Nightshift.next_switch_at(now: at(11))
    assert_equal at(4), Nightshift.next_switch_at(now: at(2))
    assert_equal at(4) + 86_400, Nightshift.next_switch_at(now: at(22))
  end

  def test_next_switch_at_survives_dst_transitions
    Nightshift.config = night_config

    with_tz('Europe/Paris') do
      # 2026-03-29 : 02:00 -> 03:00 (le jour ne fait que 23 h)
      spring = Nightshift.next_switch_at(now: Time.new(2026, 3, 29, 1, 0))

      assert_equal 4, spring.hour
      assert_equal 0, spring.min

      # 2026-10-25 : 03:00 -> 02:00 (le jour fait 25 h)
      autumn = Nightshift.next_switch_at(now: Time.new(2026, 10, 25, 1, 0))

      assert_equal 4, autumn.hour
      assert_equal 0, autumn.min
    end
  end

  # Branche "plus de borne aujourd'hui" : la prochaine bascule est le lendemain
  # civil, pas now + 86400 s (le 2026-03-29 ne dure que 23 h).
  def test_next_switch_at_rolls_to_the_next_calendar_day_across_dst
    Nightshift.config = night_config

    with_tz('Europe/Paris') do
      switch = Nightshift.next_switch_at(now: Time.new(2026, 3, 28, 23, 30))

      assert_equal '2026-03-29 04:00', switch.strftime('%Y-%m-%d %H:%M')
    end
  end

  def test_configured_backend_ignores_the_schedule
    Nightshift.config = night_config(skills: { 'haml-migration' => {}, 'bugfix' => { backend: 'frontier' } })

    assert_equal 'claude-ds4', Nightshift.configured_backend('haml-migration').harness
    assert_equal 'claude', Nightshift.configured_backend('bugfix').harness
  end

  # Deux fenetres collees vers le meme backend : 00:00 est une borne, pas une
  # bascule. Et une fenetre qui pointe le default_backend ne change rien du tout.
  def test_next_switch_at_ignores_boundaries_that_change_nothing
    Nightshift.config = build_config(
      backends: {
        'local' => Nightshift::Core::LLMBackend.new(name: 'local', harness: 'claude-ds4', concurrency: 1),
        'frontier' => Nightshift::Core::LLMBackend.new(name: 'frontier', harness: 'claude', concurrency: 5)
      },
      default_backend: 'local',
      schedule: [
        Nightshift::Core::BackendWindow.new(backend: 'frontier', from_min: 20 * 60, to_min: 0),
        Nightshift::Core::BackendWindow.new(backend: 'frontier', from_min: 0, to_min: 4 * 60)
      ],
      skills: { 'haml-migration' => {} }
    )

    assert_equal at(4) + 86_400, Nightshift.next_switch_at(now: at(22))
    assert_equal at(20), Nightshift.next_switch_at(now: at(11))
  end

  def test_next_switch_at_is_nil_when_the_window_matches_the_default
    Nightshift.config = build_config(
      backends: { 'local' => Nightshift::Core::LLMBackend.new(name: 'local', harness: 'claude-ds4', concurrency: 1) },
      default_backend: 'local',
      schedule: [Nightshift::Core::BackendWindow.new(backend: 'local', from_min: 20 * 60, to_min: 4 * 60)],
      skills: { 'haml-migration' => {} }
    )

    assert_nil Nightshift.next_switch_at(now: at(11))
  end

  def test_no_schedule_means_next_switch_is_nil
    Nightshift.config = night_config
    Nightshift.config.instance_variable_set(:@schedule, [])

    assert_nil Nightshift.next_switch_at(now: at(11))
    assert_equal 'claude-ds4', Nightshift.runner_for('haml-migration', now: at(22))
  end

  def test_window_parse_time_reads_quoted_hours
    assert_equal 0, Nightshift::Core::BackendWindow.parse_time('00:00')
    assert_equal 1200, Nightshift::Core::BackendWindow.parse_time('20:00')
    assert_equal 1230, Nightshift::Core::BackendWindow.parse_time('20:30')
  end

  def test_window_parse_time_rejects_unquoted_and_malformed_hours
    # YAML lit `20:00` non quoté comme l'entier 72000 : on echoue au chargement.
    [72_000, '20h', '25:00', '20:60', nil].each do |bad|
      capture_io do
        assert_raises(SystemExit) { Nightshift::Core::BackendWindow.parse_time(bad) }
      end
    end
  end

  def test_schedule_entry_must_be_a_hash
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, '.nightshift.yml'), <<~YAML)
        backends:
          local:
            harness: claude-ds4
        default_backend: local
        schedule:
          - "20:00-04:00"
      YAML

      capture_io do
        assert_raises(SystemExit) { Nightshift::Config.new(repo_path: dir) }
      end
    end
  end

  def test_schedule_must_be_a_list
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, '.nightshift.yml'), <<~YAML)
        backends:
          local:
            harness: claude-ds4
        default_backend: local
        schedule:
          from: "20:00"
          to: "04:00"
          backend: local
      YAML

      capture_io do
        assert_raises(SystemExit) { Nightshift::Config.new(repo_path: dir) }
      end
    end
  end

  def test_config_from_yaml_with_schedule
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, '.nightshift.yml'), <<~YAML)
        backends:
          local:
            harness: claude-ds4
            concurrency: 1
          frontier:
            harness: claude
            concurrency: 5
        default_backend: local
        schedule:
          - from: "20:00"
            to: "04:00"
            backend: frontier
        skills:
          haml-migration: {}
      YAML

      config = Nightshift::Config.new(repo_path: dir)

      assert_equal 'claude', config.runner(now: at(23))
      assert_equal 'claude-ds4', config.runner(now: at(9))
      assert_equal 'frontier', config.active_window(now: at(23)).backend
      assert_nil config.active_window(now: at(9))
    end
  end

  def test_config_from_yaml_with_backends
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, '.nightshift.yml'), <<~YAML)
        backends:
          local:
            harness: claude-ds4
            concurrency: 1
          frontier:
            harness: claude
            concurrency: 4
        default_backend: local
        skills:
          fast-skill:
            scan: "**/*.rb"
            backend: frontier
          slow-skill:
            scan: "**/*.haml"
      YAML

      config = Nightshift::Config.allocate
      config.send(:initialize, repo_path: dir)

      assert_equal 'claude-ds4', config.runner
      assert_equal 'claude', config.backend_for('fast-skill').harness
      assert_equal 4, config.backend_for('fast-skill').concurrency
      assert_equal 'claude-ds4', config.backend_for('slow-skill').harness
      assert_equal 1, config.backend_for('slow-skill').concurrency
    end
  rescue SystemExit
    skip 'preconditions not met in test environment'
  end

  def test_config_without_backends_uses_default
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, '.nightshift.yml'), <<~YAML)
        skills:
          test-skill:
            scan: "**/*.rb"
      YAML

      config = Nightshift::Config.allocate
      config.send(:initialize, repo_path: dir)

      assert_equal 'claude', config.runner
      assert_equal 'claude', config.backend_for('test-skill').harness
      assert_equal 1, config.backend_for('test-skill').concurrency
    end
  rescue SystemExit
    skip 'preconditions not met in test environment'
  end

  private

  def build_config(backends:, default_backend:, skills:, schedule: [])
    Nightshift::Config.allocate.tap do |c|
      c.instance_variable_set(:@repo_path, '/tmp/test-repo')
      c.instance_variable_set(:@backends, backends)
      c.instance_variable_set(:@default_backend_name, default_backend)
      c.instance_variable_set(:@schedule, schedule)
      c.instance_variable_set(:@skills, skills)
    end
  end

  def night_config(skills: { 'haml-migration' => {} })
    build_config(
      backends: {
        'local' => Nightshift::Core::LLMBackend.new(name: 'local', harness: 'claude-ds4', concurrency: 1),
        'frontier' => Nightshift::Core::LLMBackend.new(name: 'frontier', harness: 'claude', concurrency: 5)
      },
      default_backend: 'local',
      schedule: [
        Nightshift::Core::BackendWindow.new(backend: 'frontier', from_min: 20 * 60, to_min: 4 * 60)
      ],
      skills: skills
    )
  end

  def at(hour, min = 0) = Time.new(2026, 9, 10, hour, min, 0)

  def with_tz(zone)
    previous = ENV['TZ']
    ENV['TZ'] = zone
    yield
  ensure
    ENV['TZ'] = previous
  end
end
