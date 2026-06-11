# typed: false
#
# CLI::Backlog — CRUD sur le backlog de skills
#
# Le backlog contient les items à traiter par chaque skill (fichiers à migrer,
# specs à optimiser, etc.). Le reconciler pioche dans le backlog pour lancer
# les skills automatiquement.
#
#   add   — Ajoute un item manuellement
#   scan  — Scanne le repo et alimente le backlog via glob ou scan_proc
#   list  — Liste les items (filtrable par skill)
#   skip  — Marque un item failed comme skipped (abandon)
#   retry — Remet un item failed/skipped en pending (reset retries)
#
# Usage :
#   nightshift backlog add haml-migration app/views/foo.html.haml
#   nightshift backlog scan haml-migration
#   nightshift backlog list [SKILL]
#   nightshift backlog skip 42
#   nightshift backlog retry 42

module Nightshift
  class CLI
    class Backlog < Thor
      def self.exit_on_failure? = true

      desc "add SKILL ITEM", "Add item to skill backlog"
      def add(skill, item)
        store.add_backlog(skill, item)
        puts "nightshift: added #{item} to #{skill} backlog"
      end

      desc "scan SKILL", "Scan repo for backlog items"
      def scan(skill)
        config = Nightshift::SKILLS[skill]
        abort "nightshift: unknown skill '#{skill}' (known: #{Nightshift.skill_names.join(', ')})" unless config
        repo_path = ENV.fetch("NIGHTSHIFT_REPO")

        if config[:scan_proc]
          count = config[:scan_proc].call(repo_path, store)
          puts "nightshift: scan_proc added #{count} items for #{skill}"
          return
        end

        priority_map = config[:priority_map]
        files = Dir.glob("#{repo_path}/#{config[:scan]}")
        files.each do |f|
          relative = f.sub("#{repo_path}/", "")
          priority = resolve_priority(relative, priority_map)
          store.add_backlog(skill, relative, priority: priority)
        end
        puts "nightshift: scanned #{files.size} files for #{skill}"
      end

      desc "list [SKILL]", "List backlog items, optionally filtered by skill"
      def list(skill_filter = nil)
        items = store.all_backlog(skill: skill_filter)

        icons = { "pending" => "⬜", "running" => "🔄", "pr_open" => "🔵",
                  "done" => "✅", "failed" => "❌", "skipped" => "⏭" }

        puts ""
        items.each do |item|
          icon = icons[item.status] || "?"
          extra = ""
          extra = " PR##{item.pr_number}" if item.pr_number
          extra += " (#{item.failure_reason})" if item.failure_reason
          prio = item.priority.to_i > 0 ? " p:#{item.priority}" : ""
          puts "  #{icon} ##{item.id} [#{item.skill}] #{item.item}#{extra}#{prio}"
        end
        puts ""
        counts = items.group_by(&:status).transform_values(&:size)
        puts "  #{items.size} items: #{counts.map { |k, v| "#{v} #{k}" }.join(", ")}"
        puts ""
      end

      desc "skip ID", "Skip a failed backlog item"
      def skip(id)
        item = store.get_backlog_item(id)
        abort "nightshift: backlog item ##{id} not found" unless item
        unless item.status == "failed"
          abort "nightshift: can only skip failed items (current: #{item.status})"
        end
        store.update_backlog_status(item.id, "skipped")
        puts "nightshift: skipped backlog item ##{id} (#{item.item})"
      end

      desc "retry ID", "Retry a failed/skipped backlog item"
      def retry_item(id)
        item = store.get_backlog_item(id)
        abort "nightshift: backlog item ##{id} not found" unless item
        unless %w[failed skipped].include?(item.status)
          abort "nightshift: can only retry failed/skipped items (current: #{item.status})"
        end
        store.retry_backlog_item(item.id)
        puts "nightshift: ⬜ ##{id} #{item.item} → pending (retry_count reset)"
      end
      map "retry" => :retry_item

      private

      def store = CLI.store

      def resolve_priority(path, priority_map)
        return 0 unless priority_map
        priority_map.each do |pattern, prio|
          return prio if path.match?(pattern)
        end
        1
      end
    end
  end
end
