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

  # --- Section repos: ---

  # Un `.nightshift.yml` ecrit avant cette section doit continuer de marcher :
  # sans repli, `content_paths` serait vide et *tous* les diffs des cinq skills
  # existants seraient classes no_diff.
  def test_config_without_repos_section_falls_back_to_host_repo
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, '.nightshift.yml'), "skills:\n  haml-migration:\n    batch_size: 5\n")
      config = Nightshift::Config.allocate
      config.send(:initialize, repo_path: dir)

      app = config.repos.fetch('app')
      assert_equal dir, app.path
      assert_equal Nightshift::Config::DEFAULT_CONTENT_ALLOW, app.content_allow
      assert_equal dir, config.repo_path_for('haml-migration')
    end
  end

  def test_config_parses_repos_and_resolves_skill_repo
    Dir.mktmpdir do |dir|
      doc = File.join(dir, 'doc')
      Dir.mkdir(doc)
      File.write(File.join(dir, '.nightshift.yml'), <<~YAML)
        repos:
          app:
            path: .
            content_paths:
              allow: [app, lib]
          doc:
            path: doc
            slug: org/doc
            main_branch: trunk
            content_paths:
              deny: [".gitbook"]
            worktree:
              claude:
                skills: all
                agents: [doc-pr-analyzer]
        skills:
          doc-release-sync:
            repo: doc
      YAML

      config = Nightshift::Config.allocate
      config.send(:initialize, repo_path: dir)

      assert_equal doc, config.repo_path_for('doc-release-sync')
      assert_equal dir, config.repo_path_for('haml-migration'), 'defaut = repo hote'

      repo = config.repo_for('doc-release-sync')
      assert_equal 'trunk', repo.main_branch
      assert_equal 'org/doc', repo.slug
      assert_nil repo.worktree_skills, '`all` doit valoir « tout embarquer »'
      assert_equal ['doc-pr-analyzer'], repo.worktree_agents
      assert repo.content?('api-graphql/README.md')
      refute repo.content?('.gitbook/assets/x.png')
    end
  end

  # Un skill qui vise un repo inexistant commiterait dans le repo hote : on
  # echoue au demarrage plutot qu'a 3h du matin dans un worktree.
  def test_config_aborts_on_unknown_skill_repo
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, '.nightshift.yml'), <<~YAML)
        repos:
          app:
            path: .
            content_paths:
              allow: [lib]
        skills:
          doc-release-sync:
            repo: dco
      YAML

      config = Nightshift::Config.allocate
      err = assert_raises(SystemExit) { config.send(:initialize, repo_path: dir) }
      refute_predicate err.status, :zero?
    end
  end

  def test_config_aborts_when_content_paths_is_empty
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, '.nightshift.yml'), <<~YAML)
        repos:
          app:
            path: .
            content_paths:
              allow: []
      YAML

      config = Nightshift::Config.allocate
      assert_raises(SystemExit) { config.send(:initialize, repo_path: dir) }
    end
  end

  private

  def build_config(backends:, default_backend:, skills:)
    Nightshift::Config.allocate.tap do |c|
      c.instance_variable_set(:@repo_path, '/tmp/test-repo')
      c.instance_variable_set(:@backends, backends)
      c.instance_variable_set(:@default_backend_name, default_backend)
      c.instance_variable_set(:@skills, skills)
    end
  end
end
