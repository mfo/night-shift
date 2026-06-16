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
      YAML

      # Stub preconditions check
      config = Nightshift::Config.allocate
      config.send(:initialize, repo_path: dir)

      assert_equal 'claude-ds4', config.runner
    end
  rescue SystemExit
    # check_preconditions! may abort if tmux/gh/claude not found in test env
    skip 'preconditions not met in test environment'
  end

  def test_per_skill_runner_override_in_yaml
    Dir.mktmpdir do |dir|
      yaml_path = File.join(dir, '.nightshift.yml')
      File.write(yaml_path, <<~YAML)
        runner: claude
        skills:
          fast-skill:
            scan: "**/*.rb"
            runner: claude-ds4
          slow-skill:
            scan: "**/*.haml"
      YAML

      config = Nightshift::Config.allocate
      config.send(:initialize, repo_path: dir)

      assert_equal 'claude', config.runner
      assert_equal 'claude-ds4', config.skills['fast-skill'][:runner]
      assert_nil config.skills['slow-skill'][:runner]
    end
  rescue SystemExit
    skip 'preconditions not met in test environment'
  end
end
