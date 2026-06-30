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

      desc 'scan SKILL', 'Scan repo for backlog items (idempotent via reconcile)'
      method_option :yes, type: :boolean, aliases: '-y', desc: 'Skip confirmation'
      def scan(skill)
        source = BacklogSources.for(skill, Nightshift.repo_path)
        abort "nightshift: skill '#{skill}' has no backlog source (known: #{BacklogSources::REGISTRY.keys.join(', ')})" unless source

        items = source.items
        plan = store.reconcile_backlog(skill, items, dry_run: true)
        stats = plan[:stats]

        if stats[:added].zero? && stats[:updated].zero? && stats[:pruned].zero?
          say_status :scan, "#{skill}: nothing to change (#{stats[:total]} items current)", :green
          return
        end

        print_reconcile_diff(plan[:changes])
        say ''
        say "  +#{stats[:added]} added, ~#{stats[:updated]} updated, -#{stats[:pruned]} pruned (#{stats[:total]} total)"
        say ''

        unless options[:yes]
          return unless yes?('  Apply? [y/N]')
        end

        store.reconcile_backlog(skill, items)
        say_status :apply, "#{skill} backlog reconciled", :green
      end

      desc 'list [SKILL]', 'List backlog items, optionally filtered by skill'
      def list(skill_filter = nil)
        backlog_items = store.all_backlog(skill: skill_filter)

        icons = { BacklogStatus::Pending => '⬜', BacklogStatus::Running => '🔄',
                  BacklogStatus::PrOpen => '🔵', BacklogStatus::Done => '✅',
                  BacklogStatus::Failed => '❌', BacklogStatus::Skipped => '⏭' }

        prio_labels = { 5 => 'highest', 4 => 'high', 3 => 'medium', 2 => 'low', 1 => 'lowest', 0 => 'later' }

        say ''
        by_status = backlog_items.group_by(&:status)
        status_order = [BacklogStatus::Running, BacklogStatus::PrOpen, BacklogStatus::Pending,
                        BacklogStatus::Failed, BacklogStatus::Done, BacklogStatus::Skipped]

        status_order.each do |status|
          group = by_status[status]
          next unless group&.any?

          icon = icons[status] || '?'
          say "  #{icon} #{status.serialize} (#{group.size})", :bold
          group.each do |bi|
            extra = ''
            extra = " PR##{bi.pr_number}" if bi.pr_number
            extra += " (#{bi.failure_reason})" if bi.failure_reason
            prio = prio_labels[bi.priority.to_i] || "p:#{bi.priority}"
            say "     ##{bi.id} #{bi.item}  [#{prio}]#{extra}"
          end
          say ''
        end

        counts = by_status.transform_keys { |k| k.serialize }.transform_values(&:size)
        prio_counts = backlog_items.group_by { |bi| prio_labels[bi.priority.to_i] || "p:#{bi.priority}" }.transform_values(&:size)
        say "  #{backlog_items.size} items: #{counts.map { |k, v| "#{v} #{k}" }.join(', ')}"
        say "  by priority: #{prio_counts.map { |k, v| "#{v} #{k}" }.join(', ')}"
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

      def print_reconcile_diff(changes)
        say ''
        changes.sort_by { |c| [{ add: 0, update: 1, prune: 2 }[c[:action]], c[:item]] }.each do |c|
          case c[:action]
          when :add
            say "  + #{c[:item]}", :green
          when :update
            say "  ~ #{c[:item]}  (p:#{c[:old_priority]} → #{c[:new_priority]})", :yellow
          when :prune
            say "  - #{c[:item]}", :red
          end
        end
      end

    end
  end
end
