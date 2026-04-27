module Nightshift
  class AutolearnMonitor
    def initialize(store:)
      @store = store
    end

    def status(skill: nil)
      puts ""
      puts "━━ autolearn status ━━"

      skills = skill ? [skill] : Nightshift.skill_names
      skills.each do |sk|
        items = @store.all_backlog(skill: sk)
        next if items.empty?

        counts = items.group_by { |i| i[:status] }.transform_values(&:size)
        total = items.size
        done = counts["done"] || 0
        failed = counts["failed"] || 0
        skipped = counts["skipped"] || 0
        pending = counts["pending"] || 0
        running = counts["running"] || 0

        cycles = @store.db[:autolearn_cycles]
          .where(backlog_item_id: items.map { |i| i[:id] })
          .order(Sequel.desc(:created_at))
          .limit(5).all

        puts ""
        puts "  #{sk} (#{total} items)"
        puts "  ✅ #{done}  🔄 #{running}  ⬜ #{pending}  ❌ #{failed}  ⏭ #{skipped}"

        if cycles.any?
          puts ""
          puts "  Last cycles:"
          cycles.each do |c|
            t = Time.at(c[:created_at]).strftime("%H:%M")
            puts "    #{t} attempt=#{c[:attempt]} verdict=#{c[:verdict]} outcome=#{c[:outcome] || '-'}"
            puts "         cause: #{c[:root_cause]}" if c[:root_cause]
          end
        end

        suggestions = @store.pending_infra_suggestions(skill: sk)
        if suggestions.any?
          puts ""
          puts "  💡 Infra suggestions (#{suggestions.size}):"
          suggestions.each do |s|
            occ = s[:occurrences] > 1 ? " (x#{s[:occurrences]})" : ""
            puts "    ##{s[:id]} [#{s[:source]}]#{occ} #{s[:description][0, 80]}"
          end
        end
      end
      puts ""
    end

    def report
      cutoff = Time.now.to_i - 86_400 # 24h
      cycles = @store.db[:autolearn_cycles]
        .where { created_at > cutoff }
        .order(:created_at).all

      if cycles.empty?
        puts "\n  Aucun cycle autolearn dans les dernieres 24h.\n"
        return
      end

      by_verdict = cycles.group_by { |c| c[:verdict] }
      item_ids = cycles.map { |c| c[:backlog_item_id] }.uniq
      items = @store.db[:backlog_items].where(id: item_ids).all
      items_by_id = items.to_h { |i| [i[:id], i] }

      success_ids = cycles.select { |c| c[:verdict] == "success" }.map { |c| c[:backlog_item_id] }.uniq
      failed_ids = (item_ids - success_ids)

      patches = cycles.select { |c| c[:skill_patch_sha] }.map { |c| c[:skill_patch_sha] }.uniq
      suggestions = @store.pending_infra_suggestions
      total_turns = cycles.sum { |c| c[:turns_used].to_i }

      puts ""
      puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      puts "  AUTOLEARN REPORT — #{Time.now.strftime('%Y-%m-%d %H:%M')}"
      puts "  Periode : dernières 24h (depuis #{Time.at(cutoff).strftime('%H:%M')})"
      puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      puts ""
      puts "  Items traites : #{item_ids.size}"
      puts "  ✅ Succes     : #{success_ids.size}"
      puts "  ❌ Echecs     : #{failed_ids.size}"
      puts "  🔄 Cycles     : #{cycles.size}"
      puts "  🧠 Turns LLM  : #{total_turns}"
      puts ""

      puts "  Verdicts :"
      by_verdict.each do |verdict, cs|
        puts "    #{verdict}: #{cs.size} cycle(s)"
      end
      puts ""

      if patches.any?
        puts "  📝 Patches skill appliques : #{patches.size}"
        patches.each { |sha| puts "    #{sha[0, 7]}" }
        puts ""
      end

      if success_ids.any?
        puts "  ✅ Items reussis :"
        success_ids.each do |id|
          item = items_by_id[id]
          pr = item[:pr_number] ? " PR##{item[:pr_number]}" : ""
          puts "    ##{id} #{item[:item]}#{pr}"
        end
        puts ""
      end

      if failed_ids.any?
        puts "  ❌ Items en echec :"
        failed_ids.each do |id|
          item = items_by_id[id]
          last_cycle = cycles.select { |c| c[:backlog_item_id] == id }.last
          cause = last_cycle[:root_cause] || last_cycle[:verdict]
          puts "    ##{id} #{item[:item]}"
          puts "         #{cause[0, 100]}"
        end
        puts ""
      end

      if suggestions.any?
        puts "  💡 Suggestions infra en attente (#{suggestions.size}) :"
        suggestions.each do |s|
          occ = s[:occurrences] > 1 ? " (x#{s[:occurrences]})" : ""
          puts "    ##{s[:id]} [#{s[:source]}]#{occ} #{s[:description][0, 100]}"
        end
        puts ""
      end

      puts "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      puts ""
    end
  end
end
