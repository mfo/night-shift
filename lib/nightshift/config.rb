# frozen_string_literal: true

require 'date'
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

    sig { params(repo_path: String).void }
    def initialize(repo_path:)
      @repo_path = repo_path
      check_preconditions!
      yaml_path = File.join(repo_path, '.nightshift.yml')
      abort "nightshift: .nightshift.yml not found in #{repo_path}" unless File.exist?(yaml_path)
      raw = YAML.safe_load_file(yaml_path, symbolize_names: true)
      @backends = parse_backends(raw[:backends] || {})
      @default_backend_name = (raw[:default_backend] || @backends.keys.first)&.to_s
      @schedule = parse_schedule(raw[:schedule] || [])
      @skills = parse_skills(raw[:skills] || {})
    end

    sig { returns(T::Array[String]) }
    def skill_names = (BacklogSources::REGISTRY.keys + @skills.keys).uniq

    sig { returns(String) }
    def db_path = File.join(@repo_path, '.nightshift', 'nightshift.db')

    # Un backend explicite au niveau du skill gagne toujours ; sinon on suit
    # la plage horaire active, et à défaut le default_backend.
    sig { params(skill_name: String, now: Time).returns(Core::LLMBackend) }
    def backend_for(skill_name, now: Time.now)
      backend_name = @skills.dig(skill_name, :backend)&.to_s || active_backend_name(now: now)
      @backends[backend_name] || DEFAULT_BACKEND
    end

    sig { params(now: Time).returns(String) }
    def runner(now: Time.now) = default_backend(now: now).harness

    sig { returns(T::Array[Core::BackendWindow]) }
    def schedule = @schedule || []

    sig { params(now: Time).returns(T.nilable(Core::BackendWindow)) }
    def active_window(now: Time.now) = schedule.find { |w| w.covers?(now) }

    sig { params(now: Time).returns(Core::LLMBackend) }
    def active_backend(now: Time.now) = @backends[active_backend_name(now: now)] || DEFAULT_BACKEND

    # Backend declare en config, sans appliquer la plage horaire. Sert aux items
    # claim avant la migration 012 : ils n'ont pas de harness enregistre et ont
    # forcement tourne sur le pin ou le default, le schedule n'existait pas.
    sig { params(skill_name: String).returns(Core::LLMBackend) }
    def configured_backend(skill_name)
      name = @skills.dig(skill_name, :backend)&.to_s || @default_backend_name.to_s
      @backends[name] || DEFAULT_BACKEND
    end

    sig { params(now: Time).returns(String) }
    def active_backend_name(now: Time.now)
      active_window(now: now)&.backend || @default_backend_name.to_s
    end

    # Prochaine bascule (début ou fin de fenêtre), nil si aucune plage configurée.
    sig { params(now: Time).returns(T.nilable(Time)) }
    def next_switch_at(now: Time.now)
      bounds = schedule.flat_map { |w| [w.from_min, w.to_min] }.uniq.sort
      return nil if bounds.empty?

      current = (now.hour * 60) + now.min
      upcoming = bounds.find { |b| b > current }
      minutes = upcoming || bounds.fetch(0)
      # Tout se calcule en date civile : un jour de changement d'heure ne fait
      # pas 24 h, donc ni `midnight + n * 60` ni `now + 86_400` ne tombent juste.
      day = Date.new(now.year, now.month, now.day)
      day += 1 unless upcoming
      Time.new(day.year, day.month, day.day, minutes / 60, minutes % 60)
    end

    private

    def default_backend(now: Time.now) = active_backend(now: now)

    def parse_schedule(raw)
      abort "nightshift: schedule doit etre une liste de fenetres, pas #{raw.class.name.downcase}" unless raw.is_a?(Array)

      raw.map do |entry|
        abort "nightshift: schedule entry invalide (#{entry.inspect}) — attendu {from, to, backend}" unless entry.is_a?(Hash)

        entry = entry.transform_keys(&:to_sym)
        name = entry[:backend]&.to_s
        abort 'nightshift: schedule entry sans backend' unless name
        abort "nightshift: schedule backend inconnu: #{name}" unless @backends.key?(name)

        from = Core::BackendWindow.parse_time(entry[:from])
        to = Core::BackendWindow.parse_time(entry[:to])
        abort "nightshift: schedule #{name}: from et to identiques (#{entry[:from]})" if from == to

        Core::BackendWindow.new(backend: name, from_min: from, to_min: to)
      end
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
