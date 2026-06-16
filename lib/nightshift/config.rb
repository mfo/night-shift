# frozen_string_literal: true

require 'yaml'

module Nightshift
  #
  # Config — Target repo configuration loader
  #
  # Reads .nightshift.yml from the target repo root, parsing skill
  # definitions (scan globs, ports, priority maps as regexes, scan_proc
  # references). Exposes the derived SQLite DB path at $REPO/.nightshift/.
  #
  class Config
    extend T::Sig

    SCAN_PROCS = {
      'n1_scanner' => ->(repo_path, store) { Integrations::N1Scanner.scan(repo_path, store) }
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

    private

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
      result
    end
  end
end
