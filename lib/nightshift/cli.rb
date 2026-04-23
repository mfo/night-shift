require "open3"

module Nightshift
  module CLI
    COMMANDS = %w[attach refresh status watch diagnose autofix brief merge open close backlog auto skill-run reset].freeze

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

      # Kill tmux window
      renderer = Renderer.new(session: session)
      renderer.close_worktree(branch)

      # Remove worktree, branch, and test DB
      Worktree.cleanup(branch)
      puts "nightshift: closed #{branch}"
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
        store.update_backlog_status(backlog_item[:id], "failed",
                                   failure_reason: result[:failure_reason])
        puts "nightshift: skill failed (#{result[:failure_reason]})"
        SkillRunner.analyze_failure(skill, item: item_path,
                                   worktree_path: worktree_path,
                                   failure_reason: result[:failure_reason])
        return
      end

      # Check pr-description.md
      desc_path = File.join(worktree_path, "pr-description.md")
      unless File.exist?(desc_path)
        store.update_backlog_status(backlog_item[:id], "failed",
                                   failure_reason: "no_pr_description")
        puts "nightshift: skill succeeded but no pr-description.md"
        SkillRunner.analyze_failure(skill, item: item_path,
                                   worktree_path: worktree_path,
                                   failure_reason: "no_pr_description")
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

      if config[:inventory]
        scan_from_inventory(skill, config, repo_path)
      else
        files = Dir.glob("#{repo_path}/#{config[:scan]}")
        files.each { |f| store.add_backlog(skill, f.sub("#{repo_path}/", "")) }
        puts "nightshift: scanned #{files.size} files for #{skill}"
      end
    end

    def scan_from_inventory(skill, config, _repo_path)
      inventory_path = config[:inventory]
      abort "nightshift: inventory not found: #{inventory_path}" unless File.exist?(inventory_path)

      entries = parse_inventory(File.read(inventory_path))
      entries.each { |e| store.add_backlog(skill, e[:file], priority: e[:priority]) }
      puts "nightshift: loaded #{entries.size} items from inventory (sorted by CI time)"
    end

    def parse_inventory(content)
      entries = []
      content.each_line do |line|
        # Match inventory table rows: | U01 | `spec/path/file_spec.rb` | ... | 23.55s | ...
        match = line.match(/\|\s*[US]\d+\s*\|\s*`([^`]+)`\s*\|[^|]*\|\s*([\d.]+)s\s*\|/)
        next unless match
        file = match[1]
        time_s = match[2].to_f
        # Priority = time in centiseconds (higher = slower = picked first)
        entries << { file: file, priority: (time_s * 100).to_i }
      end
      entries
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
