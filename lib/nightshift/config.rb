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

    SCAN_PROCS = {
      'n1_scanner' => ->(repo_path) { Integrations::N1Scanner.scan(repo_path) },
      'flaky_ci_scanner' => ->(repo_path) { Integrations::FlakyCiScanner.scan(repo_path) }
    }.freeze

    SCAN_FILTERS = {
      'i18n-hardcoded' => ->(repo_path, item) { Integrations::I18nFilter.hardcoded?(repo_path, item) }
    }.freeze

    DEFAULT_BACKEND = Core::LLMBackend.new(name: 'default', harness: 'claude', concurrency: 1).freeze

    attr_reader :repo_path, :skills, :backends

    REQUIRED_BINARIES = %w[gh].freeze

    sig { params(repo_path: String).void }
    def initialize(repo_path:)
      @repo_path = repo_path
      check_preconditions!
      yaml_path = File.join(repo_path, '.nightshift.yml')
      abort "nightshift: .nightshift.yml not found in #{repo_path}" unless File.exist?(yaml_path)
      raw = YAML.safe_load_file(yaml_path, symbolize_names: true)
      @backends = parse_backends(raw[:backends] || {})
      @default_backend_name = (raw[:default_backend] || @backends.keys.first)&.to_s
      @skills = parse_skills(raw.fetch(:skills))
    end

    sig { returns(T::Array[String]) }
    def skill_names = @skills.keys

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

    def normalize(name, cfg)
      result = cfg.transform_keys(&:to_sym)
      if result[:priority_map]
        result[:priority_map] = result[:priority_map].transform_keys { |k| Regexp.new(k.to_s) }
      end
      if result[:scan_proc]
        proc_name = result[:scan_proc].to_s
        result[:scan_proc] = SCAN_PROCS.fetch(proc_name) { abort "nightshift: unknown scan_proc '#{proc_name}'" }
      end
      result[:scan_filter] = SCAN_FILTERS[name]
      result
    end
  end
end
