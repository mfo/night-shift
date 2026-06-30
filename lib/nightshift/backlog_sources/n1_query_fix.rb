# frozen_string_literal: true

require 'json'

module Nightshift
  module BacklogSources
    class N1QueryFix < Base
      SKYLIGHT_APP_URL = 'https://oss.skylight.io/app/applications/auuzqe8XhJIx/recent/6h/endpoints'

      sig { override.returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def scan
        patterns = parse_prosopite
        skylight = load_skylight
        by_file = group_by_source(patterns)

        by_file.map do |source_file, file_patterns|
          context = build_context(source_file, file_patterns, skylight)
          { item: source_file, context: JSON.generate(context) }
        end
      end

      sig { override.params(item: T::Hash[Symbol, T.untyped]).returns(Integer) }
      def prioritize(item)
        context = JSON.parse(item[:context], symbolize_names: true)
        waste = context[:total_waste_ms] || 0
        case waste
        when 10_000.. then 10
        when 5_000..9_999 then 8
        when 3_000..4_999 then 7
        when 1_000..2_999 then 5
        when 500..999 then 3
        when 1..499 then 1
        else 0
        end
      end

      private

      sig { returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def parse_prosopite
        path = File.join(repo_path, 'tmp', 'prosopite.log')
        return [] unless File.exist?(path)

        patterns = []
        current = nil

        File.foreach(path) do |line|
          line = line.strip
          if line.match?(/^SELECT\s|^UPDATE\s|^INSERT\s|^DELETE\s/i)
            current = { sql: line, call_stack: [], table: extract_table(line) }
          elsif current && line.match?(%r{app/|lib/|spec/})
            current[:call_stack] << line
          elsif current && line.empty?
            patterns << current if current[:table]
            current = nil
          end
        end
        patterns << current if current&.dig(:table)

        patterns
      end

      sig { params(sql: String).returns(T.nilable(String)) }
      def extract_table(sql)
        match = sql.match(/\bFROM\s+[`"]?(\w+)[`"]?/i)
        match ? match[1] : nil
      end

      sig { returns(T::Hash[String, T::Hash[Symbol, T.untyped]]) }
      def load_skylight
        path = File.join(repo_path, 'tmp', 'skylight-endpoints.json')
        return {} unless File.exist?(path)

        data = JSON.parse(File.read(path))
        endpoints = data.is_a?(Array) ? data : (data['endpoints'] || data['data'] || [])

        by_name = {}
        endpoints.each do |ep|
          name = ep['name'] || ep['endpoint']
          next unless name

          by_name[name] = {
            count: ep['count'] || ep['rpm'],
            p95_ms: ep['latencyP95'] || ep['p95'],
            n1_inspections: ep.dig('inspections', 'nPlusOneQuery') || 0
          }
        end
        by_name
      rescue JSON::ParserError
        {}
      end

      sig { params(patterns: T::Array[T::Hash[Symbol, T.untyped]]).returns(T::Hash[String, T::Array[T::Hash[Symbol, T.untyped]]]) }
      def group_by_source(patterns)
        by_file = Hash.new { |h, k| h[k] = [] }

        patterns.each do |pattern|
          source = find_source_file(pattern)
          next unless source

          by_file[source] << pattern
        end

        by_file
      end

      sig { params(pattern: T::Hash[Symbol, T.untyped]).returns(T.nilable(String)) }
      def find_source_file(pattern)
        table = pattern[:table]
        return nil unless table

        singular = table.chomp('s')
        model_path = "app/models/#{singular}.rb"
        return model_path if File.exist?(File.join(repo_path, model_path))

        pattern[:call_stack]&.each do |frame|
          match = frame.match(%r{(app/models/\S+\.rb)})
          return match[1] if match
        end

        nil
      end

      sig { params(source_file: String, patterns: T::Array[T::Hash[Symbol, T.untyped]], skylight_data: T::Hash[String, T::Hash[Symbol, T.untyped]]).returns(T::Hash[Symbol, T.untyped]) }
      def build_context(source_file, patterns, skylight_data)
        n1_patterns = patterns.map do |p|
          endpoint_data = find_endpoints_for_table(p[:call_stack], skylight_data)
          {
            table: p[:table],
            sql_pattern: p[:sql][0, 200],
            endpoints: endpoint_data,
            test_files: extract_test_files(p[:call_stack])
          }
        end

        total_waste = n1_patterns.sum do |p|
          p[:endpoints].sum { |e| e[:waste_ms].to_i }
        end

        {
          source_file: source_file,
          n1_patterns: n1_patterns.uniq { |p| p[:table] },
          total_waste_ms: total_waste,
          skylight_app_url: SKYLIGHT_APP_URL
        }
      end

      sig { params(call_stack: T.nilable(T::Array[String]), skylight_data: T::Hash[String, T::Hash[Symbol, T.untyped]]).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def find_endpoints_for_table(call_stack, skylight_data)
        return [] if skylight_data.empty?

        controllers = (call_stack || []).filter_map do |frame|
          match = frame.match(%r{app/controllers/(\S+)_controller\.rb.*:in.*['`](\w+)})
          next unless match

          controller_path = match[1].split('/').map { |p| p.split('_').map(&:capitalize).join }.join('::')
          "#{controller_path}Controller##{match[2]}"
        end.uniq

        controllers.filter_map do |ctrl|
          ep = skylight_data.find { |name, _| name.include?(ctrl) }
          next unless ep

          name, data = ep
          rpm = (data[:count].to_f / 6).round
          {
            name: name,
            rpm: rpm,
            p95_ms: data[:p95_ms],
            avg_reps: 3,
            waste_ms: rpm * 3 * 1
          }
        end
      end

      sig { params(call_stack: T.nilable(T::Array[String])).returns(T::Array[String]) }
      def extract_test_files(call_stack)
        (call_stack || []).filter_map do |frame|
          match = frame.match(%r{(spec/\S+_spec\.rb)})
          match ? match[1] : nil
        end.uniq
      end
    end
  end
end
