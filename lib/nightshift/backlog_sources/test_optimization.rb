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

      sig { override.params(item: T::Hash[Symbol, T.untyped]).returns(Integer) }
      def prioritize(item)
        duration = spec_duration(item[:item])
        case duration
        when 60.. then 10
        when 30..59 then 8
        when 15..29 then 6
        when 5..14 then 4
        when 1..4 then 2
        else 0
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
