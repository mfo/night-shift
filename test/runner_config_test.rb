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

  def test_runner_for_skill_falls_back_to_global
    config = Nightshift::Config.allocate.tap do |c|
      c.instance_variable_set(:@repo_path, '/tmp/test-repo')
      c.instance_variable_set(:@runner, 'claude-ds4')
      c.instance_variable_set(:@skills, {
        'haml-migration' => { scan: 'app/views/**/*.html.haml' }
      })
    end
    Nightshift.config = config

    assert_equal 'claude-ds4', Nightshift.runner_for('haml-migration')
  end

  def test_global_runner_from_yaml
    Dir.mktmpdir do |dir|
      yaml_path = File.join(dir, '.nightshift.yml')
      File.write(yaml_path, <<~YAML)
        runner: claude-ds4
        skills:
          test-skill:
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
