require "open3"

module Nightshift
  module CLI
    COMMANDS = %w[attach refresh status watch diagnose autofix brief merge open close backlog auto skill-run reset autolearn-status autolearn-report].freeze

    BINSTUB = File.expand_path("../../bin/nightshift-rb", __dir__).freeze

    module_function

    def store
      @store ||= Store.new
    end

    def run(args)
      cmd = args.shift
      case cmd
      when "status"    then cmd_status(args)
      when "refresh"   then cmd_refresh(args)
      when "merge"     then cmd_merge(args)
      when "brief"     then cmd_brief(args)
      when "diagnose"  then cmd_diagnose(args)
      when "autofix"   then cmd_autofix(args)
      when "watch"     then cmd_watch(args)
      when "attach"    then cmd_attach(args)
      when "open"      then cmd_open(args)
      when "close"     then cmd_close(args)
      when "reset"     then cmd_reset(args)
      when "backlog"   then cmd_backlog(args)
      when "auto"      then cmd_auto(args)
      when "skill-run" then cmd_skill_run(args)
      when "autolearn-status" then cmd_autolearn_status(args)
      when "autolearn-report" then cmd_autolearn_report(args)
      else
        usage
      end
    end

    def cmd_status(_args)

      puts ""
      store.all_prs.each do |row|
        pr = PR.from_db(row)
        puts "  #{pr.badge}  ##{pr.number}  #{pr.branch}"
      end
      puts ""
    end

    def cmd_refresh(_args)
      prs = GitHub.fetch_prs
      renderer = Renderer.new
      reconciler = Reconciler.new(store: store, renderer: renderer)
      reconciler.reconcile(prs)
      puts "#{Time.now.strftime('%H:%M:%S')} Refreshed (#{prs.size} PRs fetched, worktree-centric)"
    rescue GitHub::Error => e
      $stderr.puts e.message
    end

    def cmd_merge(args)
      pr_number = args.shift or abort("usage: nightshift merge <pr-number>")
      system("gh", "pr", "merge", pr_number, "--auto", "--squash",
             chdir: ENV.fetch("NIGHTSHIFT_REPO"))
    end

    def cmd_brief(_args)

      Brief.generate(store)
    end

    def cmd_diagnose(args)
      pr_number = args.shift or abort("usage: nightshift diagnose <pr-number>")
      Diagnose.run(pr_number)
    end

    def cmd_autofix(args)
      pr_number = args.shift or abort("usage: nightshift autofix <pr-number>")

      Autofix.run(pr_number, store: store)
    end

    def cmd_watch(_args)
      interval = ENV.fetch("NIGHTSHIFT_WATCH_INTERVAL").to_i
      loop do
        cmd_refresh([])
        sleep interval
      end
    end

    def cmd_attach(_args)
      Attach.run
    end

    def cmd_open(args)
      branch = args.shift or abort("usage: nightshift open <branch>")
      repo_path = ENV.fetch("NIGHTSHIFT_REPO")
      session = ENV.fetch("NIGHTSHIFT_SESSION")
      wt_path = File.join(File.dirname(repo_path), branch)

      unless system("git", "-C", repo_path, "worktree", "add", wt_path, "main", "-b", branch)
        abort "nightshift: failed to create worktree #{branch}"
      end

      system("tmux", "new-window", "-t", session, "-n", "🔨 #{branch}", "-c", wt_path)
      puts "nightshift: opened #{branch}"
    end

    def cmd_close(args)
      branch = args.shift or abort("usage: nightshift close <branch>")
      session = ENV.fetch("NIGHTSHIFT_SESSION")

      # Sync backlog: if item is running/pr_open, mark as failed

      item = store.backlog_by_branch(branch)
      if item && %w[running pr_open].include?(item[:status])
        store.update_backlog_status(item[:id], "failed", failure_reason: "manual_close")
        puts "nightshift: backlog item marked failed (manual_close)"
      end

      # Remove worktree, branch, and test DB BEFORE killing the window
      # (close_worktree kills the tmux window we're running in → SIGHUP)
      Worktree.cleanup(branch)
      puts "nightshift: closed #{branch}"

      # Kill tmux window LAST (may kill our own process)
      renderer = Renderer.new(session: session)
      renderer.close_worktree(branch)
    end

    def cmd_reset(args)
      skill = args.shift or abort("usage: nightshift reset <skill>")
      session = ENV.fetch("NIGHTSHIFT_SESSION")
      renderer = Renderer.new(session: session)

      items = store.all_backlog(skill: skill).select { |i|
        %w[running failed].include?(i[:status]) || (i[:status] == "pending" && i[:branch])
      }
      if items.empty?
        puts "nightshift: nothing to reset for #{skill}"
        return
      end

      items.each do |item|
        if item[:branch]
          renderer.close_worktree(item[:branch])
          Worktree.cleanup(item[:branch])
        end
        store.update_backlog_status(item[:id], "pending", branch: nil, failure_reason: nil)
        puts "  ⬜ ##{item[:id]} #{item[:item]} → pending"
      end
      puts "nightshift: reset #{items.size} item(s) for #{skill}"
    end

    def cmd_auto(_args)
      cmd_refresh([])
      cmd_watch([])
    end

    def cmd_skill_run(args)
      skill = args.shift or abort("usage: nightshift skill-run <skill> <item>")
      item_path = args.shift or abort("usage: nightshift skill-run <skill> <item>")
      worktree_path = Dir.pwd

      result = SkillRunner.run(skill, item: item_path, worktree_path: worktree_path)

      branch, = Open3.capture2("git", "rev-parse", "--abbrev-ref", "HEAD",
                               chdir: worktree_path)
      branch = branch.strip
      backlog_item = store.backlog_by_branch(branch)

      unless backlog_item
        puts "nightshift: no backlog item for branch #{branch}"
        return
      end

      unless result[:success]
        handle_skill_failure(skill, item_path, worktree_path, backlog_item, result)
        return
      end

      # Check pr-description.md
      desc_path = File.join(worktree_path, "pr-description.md")
      unless File.exist?(desc_path)
        handle_skill_failure(skill, item_path, worktree_path, backlog_item,
                             result.merge(failure_reason: "no_pr_description"))
        return
      end

      # Push
      unless system("git", "push", "-u", "origin", branch, chdir: worktree_path)
        store.update_backlog_status(backlog_item[:id], "failed",
                                   failure_reason: "push_error")
        puts "nightshift: push failed"
        return
      end

      # Create PR
      body = File.read(desc_path)
      pr_url, = Open3.capture2("gh", "pr", "create", "--head", branch,
                               "--fill", "--body", body, chdir: worktree_path)
      pr_number = pr_url.strip.split("/").last.to_i

      store.update_backlog_status(backlog_item[:id], "pr_open",
                                 pr_number: pr_number, branch: branch)
      puts "nightshift: PR ##{pr_number} created"

      # Record success in autolearn_cycles
      record_autolearn_cycle(backlog_item, verdict: "success", outcome: "improved",
                             log_path: result[:log_path], turns: result[:turns_used])
    end

    def handle_skill_failure(skill, item_path, worktree_path, backlog_item, result)
      failure_reason = result[:failure_reason]
      retry_count = backlog_item[:retry_count].to_i

      puts "nightshift: skill failed (#{failure_reason}) — invoking judge"

      # Judge: analyze the failure
      verdict = Judge.evaluate(skill, item: item_path,
                               log_path: result[:log_path],
                               failure_reason: failure_reason)

      puts "  ┌─ verdict: #{verdict[:verdict]} (confidence: #{verdict[:confidence]})"
      puts "  │  cause: #{verdict[:root_cause]}"
      puts "  └─ patch: #{verdict[:suggested_patch] ? 'yes' : 'none'}"

      # Record the cycle
      record_autolearn_cycle(backlog_item, verdict: verdict[:verdict],
                             root_cause: verdict[:root_cause],
                             suggested_patch: verdict[:suggested_patch],
                             log_path: result[:log_path], turns: result[:turns_used])

      # Store infra suggestion if infra_error
      if verdict[:verdict] == "infra_error" && verdict[:root_cause]
        store.add_infra_suggestion(skill: skill, description: verdict[:root_cause],
                                   source: "judge", backlog_item_id: backlog_item[:id])
        puts "  💡 infra suggestion enregistree"
      end

      # Decide: retry or stop
      if Judge.retryable?(verdict, retry_count)
        # Apply patch if skill_defect with good confidence
        if verdict[:verdict] == "skill_defect" && verdict[:suggested_patch] && verdict[:confidence] >= 0.5
          apply_skill_patch(skill, verdict[:suggested_patch])
        end

        # Clean up worktree before reset — the reconciler will create a fresh one
        branch, = Open3.capture2("git", "rev-parse", "--abbrev-ref", "HEAD",
                                 chdir: worktree_path)
        Worktree.cleanup(branch.strip)

        # Reset to pending — the reconciler will re-launch on next cycle
        store.update_backlog_status(backlog_item[:id], "pending",
                                   branch: nil, failure_reason: nil,
                                   last_verdict: verdict[:verdict])
        store.db[:backlog_items].where(id: backlog_item[:id])
          .update(retry_count: Sequel.expr(:retry_count) + 1)
        puts "  🔄 reset to pending (retry #{retry_count + 1}/#{Judge::MAX_RETRIES}) — reconciler will re-launch"
      else
        status = retry_count >= Judge::MAX_RETRIES ? "skipped" : "skipped"
        reason = retry_count >= Judge::MAX_RETRIES ? "autolearn_exhausted" : verdict[:verdict]
        store.update_backlog_status(backlog_item[:id], "skipped",
                                   failure_reason: reason,
                                   last_verdict: verdict[:verdict])
        puts "  ⏭ skipped (#{reason})"
      end
    end

    def apply_skill_patch(skill_name, patch_text)
      nightshift_dir = File.expand_path("../..", __dir__)
      patterns_path = File.join(nightshift_dir, ".claude", "skills", skill_name, "patterns.md")

      unless File.exist?(patterns_path)
        puts "  ⚠️ patterns.md not found for #{skill_name}"
        return
      end

      content = File.read(patterns_path)
      unless content.include?("## Auto-discovered pitfalls")
        content += "\n\n## Auto-discovered pitfalls\n\n<!-- Managed by autolearn. Review via kaizen synth. -->\n"
      end

      pitfall_count = content.scan(/^### AL-\d+/).size
      if pitfall_count >= 5
        puts "  🛑 5 auto-pitfalls cap reached — needs kaizen synth"
        return
      end

      pitfall_id = "AL-#{pitfall_count + 1}"
      timestamp = Time.now.strftime("%Y-%m-%d %H:%M")
      content += "\n### #{pitfall_id} (#{timestamp})\n\n#{patch_text.strip}\n"

      File.write(patterns_path, content)
      system("git", "-C", nightshift_dir, "add", patterns_path.sub("#{nightshift_dir}/", ""))
      system("git", "-C", nightshift_dir, "commit", "--no-gpg-sign",
             "-m", "autolearn(#{skill_name}): add #{pitfall_id}")
      puts "  📝 appended #{pitfall_id} to patterns.md"
    end

    def record_autolearn_cycle(backlog_item, verdict:, root_cause: nil,
                               suggested_patch: nil, log_path: nil, turns: nil, outcome: nil)
      retry_count = backlog_item[:retry_count].to_i
      store.db[:autolearn_cycles].insert(
        backlog_item_id: backlog_item[:id],
        attempt: retry_count + 1,
        verdict: verdict.to_s,
        root_cause: root_cause,
        suggested_patch: suggested_patch,
        outcome: outcome,
        log_path: log_path,
        turns_used: turns,
        created_at: Time.now.to_i
      )
    end

    def cmd_autolearn_status(args)
      skill = args.shift

      puts ""
      puts "━━ autolearn status ━━"

      skills = skill ? [skill] : Nightshift.skill_names
      skills.each do |sk|
        items = store.all_backlog(skill: sk)
        next if items.empty?

        counts = items.group_by { |i| i[:status] }.transform_values(&:size)
        total = items.size
        done = counts["done"] || 0
        failed = counts["failed"] || 0
        skipped = counts["skipped"] || 0
        pending = counts["pending"] || 0
        running = counts["running"] || 0

        cycles = store.db[:autolearn_cycles]
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

        # Suggestions infra pending
        suggestions = store.pending_infra_suggestions(skill: sk)
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

    def cmd_autolearn_report(_args)
      cutoff = Time.now.to_i - 86_400 # 24h
      cycles = store.db[:autolearn_cycles]
        .where { created_at > cutoff }
        .order(:created_at).all

      if cycles.empty?
        puts "\n  Aucun cycle autolearn dans les dernieres 24h.\n"
        return
      end

      # Agreger par verdict
      by_verdict = cycles.group_by { |c| c[:verdict] }
      item_ids = cycles.map { |c| c[:backlog_item_id] }.uniq
      items = store.db[:backlog_items].where(id: item_ids).all
      items_by_id = items.to_h { |i| [i[:id], i] }

      # Items uniques traites
      success_ids = cycles.select { |c| c[:verdict] == "success" }.map { |c| c[:backlog_item_id] }.uniq
      failed_ids = (item_ids - success_ids)

      # Patches appliques
      patches = cycles.select { |c| c[:skill_patch_sha] }.map { |c| c[:skill_patch_sha] }.uniq

      # Suggestions infra
      suggestions = store.pending_infra_suggestions

      # Tokens / turns
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

      # Repartition des verdicts
      puts "  Verdicts :"
      by_verdict.each do |verdict, cs|
        puts "    #{verdict}: #{cs.size} cycle(s)"
      end
      puts ""

      # Patches appliques
      if patches.any?
        puts "  📝 Patches skill appliques : #{patches.size}"
        patches.each { |sha| puts "    #{sha[0, 7]}" }
        puts ""
      end

      # Items en succes
      if success_ids.any?
        puts "  ✅ Items reussis :"
        success_ids.each do |id|
          item = items_by_id[id]
          pr = item[:pr_number] ? " PR##{item[:pr_number]}" : ""
          puts "    ##{id} #{item[:item]}#{pr}"
        end
        puts ""
      end

      # Items en echec avec cause
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

      # Suggestions infra
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

    def cmd_backlog(args)
      sub = args.shift
      case sub
      when "add"  then cmd_backlog_add(args)
      when "scan" then cmd_backlog_scan(args)
      when "list" then cmd_backlog_list(args)
      when "skip" then cmd_backlog_skip(args)
      else
        abort "usage: nightshift backlog <add|scan|list|skip>"
      end
    end

    def cmd_backlog_add(args)
      skill = args.shift or abort("usage: nightshift backlog add <skill> <item>")
      item = args.shift or abort("usage: nightshift backlog add <skill> <item>")

      store.add_backlog(skill, item)
      puts "nightshift: added #{item} to #{skill} backlog"
    end

    def cmd_backlog_scan(args)
      skill = args.shift or abort("usage: nightshift backlog scan <skill>")
      config = Nightshift::SKILLS[skill]
      abort "nightshift: unknown skill '#{skill}' (known: #{Nightshift.skill_names.join(', ')})" unless config
      repo_path = ENV.fetch("NIGHTSHIFT_REPO")

      files = Dir.glob("#{repo_path}/#{config[:scan]}")
      files.each { |f| store.add_backlog(skill, f.sub("#{repo_path}/", "")) }
      puts "nightshift: scanned #{files.size} files for #{skill}"
    end

    def cmd_backlog_list(args)
      skill_filter = args.shift

      items = store.all_backlog(skill: skill_filter)

      icons = { "pending" => "⬜", "running" => "🔄", "pr_open" => "🔵",
                "done" => "✅", "failed" => "❌", "skipped" => "⏭" }

      puts ""
      items.each do |item|
        icon = icons[item[:status]] || "?"
        extra = ""
        extra = " PR##{item[:pr_number]}" if item[:pr_number]
        extra += " (#{item[:failure_reason]})" if item[:failure_reason]
        prio = item[:priority].to_i > 0 ? " p:#{item[:priority]}" : ""
        puts "  #{icon} ##{item[:id]} [#{item[:skill]}] #{item[:item]}#{extra}#{prio}"
      end
      puts ""
      counts = items.group_by { |i| i[:status] }.transform_values(&:size)
      puts "  #{items.size} items: #{counts.map { |k, v| "#{v} #{k}" }.join(", ")}"
      puts ""
    end
    def cmd_backlog_skip(args)
      id = args.shift or abort("usage: nightshift backlog skip <id>")
      item = store.db[:backlog_items].where(id: id.to_i).first
      abort "nightshift: backlog item ##{id} not found" unless item
      unless item[:status] == "failed"
        abort "nightshift: can only skip failed items (current: #{item[:status]})"
      end
      store.update_backlog_status(item[:id], "skipped")
      puts "nightshift: skipped backlog item ##{id} (#{item[:item]})"
    end

    def usage
      puts "Usage: nightshift <#{COMMANDS.join('|')}>"
      exit 1
    end
  end
end
