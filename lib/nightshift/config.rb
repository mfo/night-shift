# frozen_string_literal: true

require 'yaml'

module Nightshift
  #
  # Config — Target repo configuration loader
  #
  # Reads .nightshift.yml from the target repo root, parsing skill
  # definitions, backend profiles (binary + concurrency), and scan globs.
  #
  # Backends group execution properties (binary, concurrency) and skills
  # reference them by name. This allows local models (concurrency: 1)
  # and frontier APIs (concurrency: 4) to coexist.
  #
  class Config
    extend T::Sig

    DEFAULT_BACKEND = Core::LLMBackend.new(name: 'default', harness: 'claude', concurrency: 1).freeze

    attr_reader :repo_path, :skills, :backends

    REQUIRED_BINARIES = %w[gh].freeze

    # Ce que `real_changes` filtrait en dur avant que le repo soit une entite.
    DEFAULT_CONTENT_ALLOW = %w[app spec config lib].freeze

    sig { params(repo_path: String).void }
    def initialize(repo_path:)
      @repo_path = repo_path
      check_preconditions!
      yaml_path = File.join(repo_path, '.nightshift.yml')
      abort "nightshift: .nightshift.yml not found in #{repo_path}" unless File.exist?(yaml_path)
      raw = YAML.safe_load_file(yaml_path, symbolize_names: true)
      @backends = parse_backends(raw[:backends] || {})
      @default_backend_name = (raw[:default_backend] || @backends.keys.first)&.to_s
      @skills = parse_skills(raw[:skills] || {})
      @repos = parse_repos(raw[:repos])
      validate_repos!
    end

    # Toujours au moins le repo hote. Un Config construit par morceaux — ce que
    # font les stubs de test — n'a pas forcement traverse `parse_repos` ; rendre
    # cette methode totale evite que chaque appelant ait a s'en soucier.
    sig { returns(T::Hash[String, Core::Repo]) }
    def repos
      @repos ||= { 'app' => default_app_repo }
    end

    # Le repo sur lequel un skill travaille. Defaut `app`, soit le repo hote.
    sig { params(skill_name: String).returns(Core::Repo) }
    def repo_for(skill_name)
      repos.fetch((@skills || {}).dig(skill_name, :repo)&.to_s || 'app', repos.fetch('app'))
    end

    sig { params(skill_name: String).returns(String) }
    def repo_path_for(skill_name) = repo_for(skill_name).path

    sig { returns(T::Array[String]) }
    def skill_names = (BacklogSources::REGISTRY.keys + @skills.keys).uniq

    sig { returns(String) }
    def db_path = File.join(@repo_path, '.nightshift', 'nightshift.db')

    sig { params(skill_name: String).returns(Core::LLMBackend) }
    def backend_for(skill_name)
      backend_name = @skills.dig(skill_name, :backend)&.to_s || @default_backend_name
      @backends[backend_name] || DEFAULT_BACKEND
    end

    sig { returns(String) }
    def runner = default_backend.harness

    private

    # Sans section `repos:`, on reconstruit le comportement d'avant : un seul
    # repo, celui passe a `--repo`, avec l'allowlist qui etait cablee dans
    # `real_changes`. Un `.nightshift.yml` existant continue donc de marcher —
    # sans ce repli, `content_paths` serait vide et *tous* les diffs des cinq
    # skills existants seraient classes `no_diff`.
    def parse_repos(raw)
      return { 'app' => default_app_repo } if raw.nil? || raw.empty?

      raw.transform_keys(&:to_s).each_with_object({}) do |(name, cfg), h|
        cfg = (cfg || {}).transform_keys(&:to_sym)
        content = (cfg[:content_paths] || {}).transform_keys(&:to_sym)
        worktree = (cfg[:worktree] || {}).transform_keys(&:to_sym)
        claude = (worktree[:claude] || {}).transform_keys(&:to_sym)

        h[name] = Core::Repo.new(
          name: name,
          path: File.expand_path(cfg[:path]&.to_s || @repo_path, @repo_path),
          slug: cfg[:slug]&.to_s,
          main_branch: cfg[:main_branch]&.to_s || 'main',
          content_allow: string_list(content[:allow]),
          content_deny: string_list(content[:deny]),
          worktree_skills: string_list(claude[:skills]),
          worktree_agents: string_list(claude[:agents])
        )
      end
    end

    def default_app_repo
      Core::Repo.new(name: 'app', path: @repo_path,
                     content_allow: DEFAULT_CONTENT_ALLOW.dup)
    end

    # `skills: all` vaut `nil`, soit « tout embarquer ».
    def string_list(value)
      return nil if value.nil? || value.to_s == 'all'

      Array(value).map(&:to_s)
    end

    # Chaque degradation silencieuse ci-dessous a un cout dispro : un repo mal
    # nomme fait commiter un skill dans le mauvais depot, un `content_paths`
    # vide classe tous les diffs en `no_diff`. On echoue au demarrage, avec le
    # nom du repo fautif, plutot qu'a 3h du matin dans un worktree.
    def validate_repos!
      abort 'nightshift: repos: doit declarer un repo `app`' unless @repos.key?('app')

      @repos.each_value do |repo|
        abort "nightshift: [repo=#{repo.name}] chemin introuvable: #{repo.path}" unless Dir.exist?(repo.path)

        if repo.content_allow && repo.content_deny
          abort "nightshift: [repo=#{repo.name}] content_paths: allow et deny sont exclusifs"
        end
        if repo.content_allow.nil? && repo.content_deny.nil?
          abort "nightshift: [repo=#{repo.name}] content_paths: declare `allow` ou `deny`"
        end
        if (repo.content_allow || repo.content_deny).empty?
          abort "nightshift: [repo=#{repo.name}] content_paths vide — tous les diffs seraient ignores"
        end
      end

      @skills.each do |skill, cfg|
        name = cfg[:repo]&.to_s
        next if name.nil? || @repos.key?(name)

        abort "nightshift: skill '#{skill}' vise le repo inconnu '#{name}' " \
              "(declares: #{@repos.keys.join(', ')})"
      end
    end

    def default_backend
      @backends[@default_backend_name] || DEFAULT_BACKEND
    end

    def parse_backends(raw)
      result = raw.transform_keys(&:to_s).each_with_object({}) do |(name, cfg), h|
        cfg ||= {}
        h[name] = Core::LLMBackend.new(
          name: name,
          harness: cfg[:harness]&.to_s || cfg[:binary]&.to_s || 'claude',
          concurrency: (cfg[:concurrency] || 1).to_i.clamp(1, 10)
        )
      end
      result['default'] ||= DEFAULT_BACKEND if result.empty?
      result
    end

    def parse_skills(raw)
      raw.transform_keys(&:to_s).each_with_object({}) do |(name, cfg), h|
        h[name] = normalize(name, cfg || {})
      end
    end

    def check_preconditions!
      REQUIRED_BINARIES.each do |bin|
        abort "nightshift: #{bin} not installed" unless system('command', '-v', bin, out: File::NULL, err: File::NULL)
      end
    end

    def normalize(_name, cfg)
      cfg.transform_keys(&:to_sym)
    end
  end
end
