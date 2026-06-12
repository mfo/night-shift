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
    SCAN_PROCS = {
      'n1_scanner' => ->(repo_path, store) { Integrations::N1Scanner.scan(repo_path, store) }
    }.freeze

    attr_reader :repo_path, :skills

    def initialize(repo_path:)
      @repo_path = repo_path
      yaml_path = File.join(repo_path, '.nightshift.yml')
      abort "nightshift: .nightshift.yml not found in #{repo_path}" unless File.exist?(yaml_path)
      raw = YAML.safe_load_file(yaml_path, symbolize_names: true)
      @skills = parse_skills(raw.fetch(:skills))
    end

    def skill_names = @skills.keys
    def db_path = File.join(@repo_path, '.nightshift', 'nightshift.db')

    private

    def parse_skills(raw)
      raw.transform_keys(&:to_s).each_with_object({}) do |(name, cfg), h|
        h[name] = normalize(name, cfg || {})
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
