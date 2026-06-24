# frozen_string_literal: true

module Nightshift
  module Monitoring
    #
    # AutolearnMonitor — Autolearn dashboard and reporting
    #
    # Displays per-skill status (pending/running/done/failed counts),
    # recent autolearn cycles, and a 24h report with verdict breakdown,
    # applied patches, and infra suggestions.
    #
    class AutolearnMonitor
      extend T::Sig

      sig { params(store: Core::Store).void }
      def initialize(store:)
        @store = store
      end

      sig { params(skill: T.nilable(String)).void }
      def status(skill: nil)
        puts ''
        puts '━━ autolearn status ━━'

        skills = skill ? [skill] : Nightshift.skill_names
        skills.each do |sk|
          items = @store.all_backlog(skill: sk)
          next if items.empty?

          counts = items.group_by(&:status).transform_values(&:size)
          total = items.size
          done = counts[BacklogStatus::Done] || 0
          failed = counts[BacklogStatus::Failed] || 0
          skipped = counts[BacklogStatus::Skipped] || 0
          pending = counts[BacklogStatus::Pending] || 0
          running = counts[BacklogStatus::Running] || 0

          cycles = @store.recent_cycles(items.map(&:id), limit: 5)

          puts ''
          puts "  #{sk} (#{total} items)"
          puts "  ✅ #{done}  🔄 #{running}  ⬜ #{pending}  ❌ #{failed}  ⏭ #{skipped}"

          if cycles.any?
            puts ''
            puts '  Last cycles:'
            cycles.each do |c|
              t = Time.at(c[:created_at]).strftime('%H:%M')
              puts "    #{t} attempt=#{c[:attempt]} verdict=#{c[:verdict]} outcome=#{c[:outcome] || '-'}"
              puts "         cause: #{c[:root_cause]}" if c[:root_cause]
            end
          end

          suggestions = @store.pending_infra_suggestions(skill: sk)
          next unless suggestions.any?

          puts ''
          puts "  💡 Infra suggestions (#{suggestions.size}):"
          suggestions.each do |s|
            occ = s[:occurrences] > 1 ? " (x#{s[:occurrences]})" : ''
            puts "    ##{s[:id]} [#{s[:source]}]#{occ} #{s[:description][0, 80]}"
          end
        end
        puts ''
      end

      sig { void }
      def report
        cutoff = Time.now.to_i - 86_400 * 10 # 24h
        cycles = @store.cycles_since(cutoff)

        if cycles.empty?
          puts "\n  Aucun cycle autolearn dans les dernieres 24h.\n"
          return
        end

        by_verdict = cycles.group_by { |c| c[:verdict] }
        item_ids = cycles.map { |c| c[:backlog_item_id] }.uniq
        items = @store.db[:backlog_items].where(id: item_ids).all
        items_by_id = items.to_h { |i| [i[:id], i] }

        success_ids = cycles.select { |c| c[:verdict] == 'success' }.map { |c| c[:backlog_item_id] }.uniq
        failed_ids = (item_ids - success_ids)

        patches = cycles.select { |c| c[:skill_patch_sha] }.map { |c| c[:skill_patch_sha] }.uniq
        suggestions = @store.pending_infra_suggestions
        total_turns = cycles.sum { |c| c[:turns_used].to_i }

        puts ''
        puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
        puts "  AUTOLEARN REPORT — #{Time.now.strftime('%Y-%m-%d %H:%M')}"
        puts "  Periode : dernières 24h (depuis #{Time.at(cutoff).strftime('%H:%M')})"
        puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
        puts ''
        puts "  Items traites : #{item_ids.size}"
        puts "  ✅ Succes     : #{success_ids.size}"
        puts "  ❌ Echecs     : #{failed_ids.size}"
        puts "  🔄 Cycles     : #{cycles.size}"
        puts "  🧠 Turns LLM  : #{total_turns}"
        puts ''

        puts '  Verdicts :'
        by_verdict.each do |verdict, cs|
          puts "    #{verdict}: #{cs.size} cycle(s)"
        end
        puts ''

        if patches.any?
          puts "  📝 Patches skill appliques : #{patches.size}"
          patches.each { |sha| puts "    #{sha[0, 7]}" }
          puts ''
        end

        if success_ids.any?
          puts '  ✅ Items reussis :'
          success_ids.each do |id|
            item = items_by_id[id]
            pr = item[:pr_number] ? " PR##{item[:pr_number]}" : ''
            puts "    ##{id} #{item[:item]}#{pr}"
          end
          puts ''
        end

        if failed_ids.any?
          puts '  ❌ Items en echec :'
          failed_ids.each do |id|
            item = items_by_id[id]
            last_cycle = cycles.select { |c| c[:backlog_item_id] == id }.last
            cause = last_cycle[:root_cause] || last_cycle[:verdict]
            puts "    ##{id} #{item[:item]}"
            puts "         #{cause[0, 100]}"
          end
          puts ''
        end

        if suggestions.any?
          puts "  💡 Suggestions infra en attente (#{suggestions.size}) :"
          suggestions.each do |s|
            occ = s[:occurrences] > 1 ? " (x#{s[:occurrences]})" : ''
            puts "    ##{s[:id]} [#{s[:source]}]#{occ} #{s[:description][0, 100]}"
          end
          puts ''
        end

        puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
        puts ''
      end
    end
  end
end
