require "json"
require "open3"
require "tempfile"

module Nightshift
  module Reprioritizer
    module_function

    def run(skill_name, store:)
      items = store.all_backlog(skill: skill_name)
        .select { |i| i[:status] == "pending" }
      return if items.empty?

      # Build context for the reprioritize skill
      context = {
        skill: skill_name,
        items: items.map { |i|
          {
            id: i[:id],
            item: i[:item],
            priority: i[:priority],
            context: i[:context] ? (JSON.parse(i[:context]) rescue nil) : nil
          }
        }
      }

      ctx_file = Tempfile.new(["reprio-", ".json"])
      ctx_file.write(JSON.pretty_generate(context))
      ctx_file.close

      prompt = "/reprioritize #{skill_name}"
      out, status = Open3.capture2(
        "claude", "-p", prompt,
        "--permission-mode", "acceptEdits",
        "--output-format", "text",
        "--max-turns", "30",
        { "SKILL_CONTEXT" => ctx_file.path }
      )

      unless status.success?
        puts "nightshift: reprioritize failed (exit #{status.exitstatus})"
        return
      end

      apply_updates(out, store)
    ensure
      ctx_file&.unlink
    end

    def apply_updates(raw_output, store)
      # Extract JSON from output
      start_idx = raw_output.index("{")
      return unless start_idx

      depth = 0
      end_idx = nil
      (start_idx...raw_output.length).each do |i|
        case raw_output[i]
        when "{" then depth += 1
        when "}" then depth -= 1; if depth == 0 then end_idx = i; break; end
        end
      end
      return unless end_idx

      data = JSON.parse(raw_output[start_idx..end_idx])
      updates = data["updates"] || []
      skip_ids = data["skip_ids"] || []

      updates.each do |u|
        store.update_backlog_priority(u["id"], u["priority"])
      end

      skip_ids.each do |id|
        store.update_backlog_status(id, "skipped", failure_reason: "resolved_upstream")
      end

      puts "nightshift: reprioritized #{updates.size} items, skipped #{skip_ids.size}"
      puts "  #{data['summary']}" if data["summary"]
    rescue JSON::ParserError => e
      puts "nightshift: reprioritize output not parseable: #{e.message}"
    end
  end
end
