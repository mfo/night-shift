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
        config = Nightshift.skills[skill]
        abort "nightshift: unknown skill '#{skill}' (known: #{Nightshift.skill_names.join(', ')})" unless config
        repo_path = Nightshift.repo_path

        items = if config[:scan_proc]
                  scan_with_proc(config[:scan_proc], repo_path)
                elsif config[:scan]
                  scan_with_glob(repo_path, config[:scan], config[:priority_map], filter: config[:scan_filter])
                else
                  abort "nightshift: skill '#{skill}' has no scan glob or scan_proc"
                end

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

      def scan_with_proc(proc, repo_path)
        if proc.arity == 1 || (proc.arity < 0 && proc.arity.abs - 1 <= 1)
          proc.call(repo_path)
        else
          # Legacy contract: proc(repo_path, store) → count
          # Wrap as reconcile-compatible by collecting what add_backlog receives
          items = []
          collector = Object.new
          collector.define_singleton_method(:add_backlog) do |_skill, item, priority: 0, context: nil|
            items << { item: item, priority: priority, context: context }
          end
          proc.call(repo_path, collector)
          items
        end
      end

      def scan_with_glob(repo_path, pattern, priority_map, filter: nil)
        Dir.glob("#{repo_path}/#{pattern}").filter_map do |f|
          relative = f.sub("#{repo_path}/", '')
          next if filter && !filter.call(repo_path, relative)

          { item: relative, priority: resolve_priority(relative, priority_map) }
        end
      end

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
