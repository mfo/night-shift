# frozen_string_literal: true

require 'json'

module Nightshift
  module BacklogSources
    class TestOptimization < Base
      PROFILE_PATH = 'tmp/rspec_profile.json'

      sig { override.returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def scan
        glob('spec/**/*_spec.rb')
      end

      MIN_DURATION_SECONDS = 5

      sig { override.params(item_path: String).returns(T::Boolean) }
      def relevant?(item_path)
        spec_duration(item_path) >= MIN_DURATION_SECONDS
      end

      sig { override.params(item: T::Hash[Symbol, T.untyped]).returns(Integer) }
      def prioritize(item)
        duration = spec_duration(item[:item]).to_f
        if duration >= 60 then HIGHEST
        elsif duration >= 30 then HIGH
        elsif duration >= 15 then MEDIUM
        elsif duration >= 5 then LOW
        else LOWEST
        end
      end

      private

      sig { params(spec_path: String).returns(Integer) }
      def spec_duration(spec_path)
        @durations ||= load_durations
        @durations[spec_path]&.to_f&.round || 0
      end

      sig { returns(T::Hash[String, T.untyped]) }
      def load_durations
        path = File.join(repo_path, PROFILE_PATH)
        return {} unless File.exist?(path)

        JSON.parse(File.read(path))
      rescue JSON::ParserError
        {}
      end
    end
  end
end
