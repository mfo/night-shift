# frozen_string_literal: true
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

      desc 'add SKILL ITEM', 'Add item to skill backlog'
      def add(skill, item)
        store.add_backlog(skill, item)
        say_status :add, "#{item} to #{skill} backlog", :green
      end

      desc 'scan SKILL', 'Scan repo for backlog items'
      def scan(skill)
        config = Nightshift.skills[skill]
        abort "nightshift: unknown skill '#{skill}' (known: #{Nightshift.skill_names.join(', ')})" unless config
        repo_path = Nightshift.repo_path

        if config[:scan_proc]
          count = config[:scan_proc].call(repo_path, store)
          say_status :scan, "#{count} items added for #{skill}", :green
          return
        end

        priority_map = config[:priority_map]
        files = Dir.glob("#{repo_path}/#{config[:scan]}")
        files.each do |f|
          relative = f.sub("#{repo_path}/", '')
          priority = resolve_priority(relative, priority_map)
          store.add_backlog(skill, relative, priority: priority)
        end
        say_status :scan, "#{files.size} files for #{skill}", :green
      end

      desc 'list [SKILL]', 'List backlog items, optionally filtered by skill'
      def list(skill_filter = nil)
        backlog_items = store.all_backlog(skill: skill_filter)

        icons = { BacklogStatus::Pending => '⬜', BacklogStatus::Running => '🔄',
                  BacklogStatus::PrOpen => '🔵', BacklogStatus::Done => '✅',
                  BacklogStatus::Failed => '❌', BacklogStatus::Skipped => '⏭' }

        say ''
        backlog_items.each do |backlog_item|
          icon = icons[backlog_item.status] || '?'
          extra = ''
          extra = " PR##{backlog_item.pr_number}" if backlog_item.pr_number
          extra += " (#{backlog_item.failure_reason})" if backlog_item.failure_reason
          prio = backlog_item.priority.to_i.positive? ? " p:#{backlog_item.priority}" : ''
          say "  #{icon} ##{backlog_item.id} [#{backlog_item.skill}] #{backlog_item.item}#{extra}#{prio}"
        end
        say ''
        counts = backlog_items.group_by(&:status).transform_values(&:size)
        say "  #{backlog_items.size} items: #{counts.map { |k, v| "#{v} #{k.serialize}" }.join(', ')}"
        say ''
      end

      desc 'skip ID', 'Skip a failed backlog item'
      def skip(id)
        backlog_item = store.get_backlog_item(id)
        abort "nightshift: backlog item ##{id} not found" unless backlog_item
        abort "nightshift: can only skip failed items (current: #{backlog_item.status.serialize})" unless backlog_item.status == BacklogStatus::Failed
        store.update_backlog_status(backlog_item, BacklogStatus::Skipped)
        say_status :skip, "##{id} #{backlog_item.item}", :yellow
      end

      desc 'retry ID', 'Retry a failed/skipped backlog item'
      def retry_item(id)
        backlog_item = store.get_backlog_item(id)
        abort "nightshift: backlog item ##{id} not found" unless backlog_item
        unless [BacklogStatus::Failed, BacklogStatus::Skipped].include?(backlog_item.status)
          abort "nightshift: can only retry failed/skipped items (current: #{backlog_item.status.serialize})"
        end
        store.retry_backlog_item(backlog_item)
        say_status :retry, "##{id} #{backlog_item.item} → pending (retry_count reset)", :green
      end
      map 'retry' => :retry_item

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
