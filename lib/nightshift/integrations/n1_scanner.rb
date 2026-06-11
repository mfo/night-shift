require "json"

module Nightshift
  module Integrations
  module N1Scanner
    SKYLIGHT_APP_URL = "https://oss.skylight.io/app/applications/auuzqe8XhJIx/recent/6h/endpoints"

    module_function

    # Scan Prosopite log + Skylight snapshot to build the N+1 backlog.
    # Groups patterns by source file (model/concern), not by endpoint.
    #
    # Expected data files in repo_path/tmp/:
    #   - prosopite.log : Prosopite N+1 detection output
    #   - skylight-endpoints.json : Skylight endpoint_highlights snapshot
    #
    # Returns the number of items added.
    def scan(repo_path, store)
      prosopite_path = File.join(repo_path, "tmp", "prosopite.log")
      skylight_path = File.join(repo_path, "tmp", "skylight-endpoints.json")

      patterns = parse_prosopite(prosopite_path) if File.exist?(prosopite_path)
      patterns ||= []

      skylight = load_skylight(skylight_path) if File.exist?(skylight_path)
      skylight ||= {}

      # Group by source file
      by_file = group_by_source(patterns, repo_path)

      count = 0
      by_file.each do |source_file, file_patterns|
        # Build context with Skylight data
        context = build_context(source_file, file_patterns, skylight)
        priority = calculate_priority(context)

        store.add_backlog("n1-query-fix", source_file,
                          priority: priority,
                          context: JSON.generate(context))
        count += 1
      end

      count
    end

    # Parse Prosopite log to extract N+1 patterns.
    # Prosopite format: each N+1 is a block with SQL + call stack
    def parse_prosopite(path)
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

    def extract_table(sql)
      # Extract table name from SQL: SELECT ... FROM table_name ...
      match = sql.match(/\bFROM\s+[`"]?(\w+)[`"]?/i)
      match ? match[1] : nil
    end

    # Load Skylight endpoint_highlights JSON snapshot
    def load_skylight(path)
      data = JSON.parse(File.read(path))
      endpoints = data.is_a?(Array) ? data : (data["endpoints"] || data["data"] || [])

      by_name = {}
      endpoints.each do |ep|
        name = ep["name"] || ep["endpoint"]
        next unless name
        by_name[name] = {
          count: ep["count"] || ep["rpm"],
          p95_ms: ep["latencyP95"] || ep["p95"],
          n1_inspections: ep.dig("inspections", "nPlusOneQuery") || 0
        }
      end
      by_name
    end

    # Group N+1 patterns by the model/concern file that defines the association
    def group_by_source(patterns, repo_path)
      by_file = Hash.new { |h, k| h[k] = [] }

      patterns.each do |pattern|
        source = find_source_file(pattern, repo_path)
        next unless source
        by_file[source] << pattern
      end

      by_file
    end

    # Find the model/concern file that defines the association for this N+1
    def find_source_file(pattern, repo_path)
      table = pattern[:table]
      return nil unless table

      # Try to find the model for this table
      # Convention: table "etablissements" → model "app/models/etablissement.rb"
      singular = table.chomp("s") # naive singularization
      model_path = "app/models/#{singular}.rb"
      return model_path if File.exist?(File.join(repo_path, model_path))

      # Check call stack for the first app/models or app/models/concerns file
      pattern[:call_stack]&.each do |frame|
        match = frame.match(%r{(app/models/\S+\.rb)})
        return match[1] if match
      end

      nil
    end

    # Build context JSON for a backlog item
    def build_context(source_file, patterns, skylight_data)
      n1_patterns = patterns.map do |p|
        endpoint_data = find_endpoints_for_table(p[:table], p[:call_stack], skylight_data)
        {
          table: p[:table],
          sql_pattern: p[:sql][0, 200],
          endpoints: endpoint_data,
          test_files: extract_test_files(p[:call_stack])
        }
      end

      total_waste = n1_patterns.sum { |p|
        p[:endpoints].sum { |e| e[:waste_ms].to_i }
      }

      {
        source_file: source_file,
        n1_patterns: n1_patterns.uniq { |p| p[:table] },
        total_waste_ms: total_waste,
        skylight_app_url: SKYLIGHT_APP_URL
      }
    end

    def find_endpoints_for_table(table, call_stack, skylight_data)
      return [] if skylight_data.empty?

      # Try to match call stack frames to controllers → endpoints
      controllers = (call_stack || []).filter_map { |frame|
        match = frame.match(%r{app/controllers/(\S+)_controller\.rb.*:in.*['`](\w+)})
        next unless match
        controller_path = match[1].split("/").map { |p| p.split("_").map(&:capitalize).join }.join("::")
        "#{controller_path}Controller##{match[2]}"
      }.uniq

      controllers.filter_map do |ctrl|
        ep = skylight_data.find { |name, _| name.include?(ctrl) }
        next unless ep
        name, data = ep
        rpm = (data[:count].to_f / 6).round # 6h window → per-hour
        {
          name: name,
          rpm: rpm,
          p95_ms: data[:p95_ms],
          avg_reps: 3, # conservative default, refined by reprioritize
          waste_ms: rpm * 3 * 1 # placeholder, refined by reprioritize
        }
      end
    end

    def extract_test_files(call_stack)
      (call_stack || []).filter_map { |frame|
        match = frame.match(%r{(spec/\S+_spec\.rb)})
        match ? match[1] : nil
      }.uniq
    end

    def calculate_priority(context)
      waste = context[:total_waste_ms]
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
  end
  end
end
