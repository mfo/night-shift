require "open3"

module Nightshift
  module CLI
    COMMANDS = %w[attach refresh status watch diagnose autofix brief merge open close backlog auto skill-run].freeze

    BINSTUB = File.expand_path("../../bin/nightshift-rb", __dir__).freeze

    module_function

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
      when "backlog"   then cmd_backlog(args)
      when "auto"      then cmd_auto(args)
      when "skill-run" then cmd_skill_run(args)
      else
        usage
      end
    end

    def cmd_status(_args)
      store = Store.new
      puts ""
      store.all_prs.each do |row|
        pr = PR.from_db(row)
        puts "  #{pr.badge}  ##{pr.number}  #{pr.branch}"
      end
      puts ""
    end

    def cmd_refresh(_args)
      prs = GitHub.fetch_prs
      store = Store.new
      renderer = Renderer.new
      reconciler = Reconciler.new(store: store, renderer: renderer)
      reconciler.reconcile(prs)
      puts "Refreshed (#{prs.size} PRs fetched, worktree-centric)"
    end

    def cmd_merge(args)
      pr_number = args.shift or abort("Usage: nightshift merge <pr-number>")
      system("gh", "pr", "merge", pr_number, "--auto", "--squash",
             chdir: ENV.fetch("NIGHTSHIFT_REPO"))
    end

    def cmd_brief(_args)
      store = Store.new
      Brief.generate(store)
    end

    def cmd_diagnose(args)
      pr_number = args.shift or abort("Usage: nightshift diagnose <pr-number>")
      Diagnose.run(pr_number)
    end

    def cmd_autofix(args)
      pr_number = args.shift or abort("Usage: nightshift autofix <pr-number>")
      store = Store.new
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
      branch = args.shift or abort("Usage: nightshift open <branch>")
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
      branch = args.shift or abort("Usage: nightshift close <branch>")
      repo_path = ENV.fetch("NIGHTSHIFT_REPO")
      session = ENV.fetch("NIGHTSHIFT_SESSION")
      wt_path = worktree_path_for_branch(repo_path, branch)

      # Sync backlog: if item is running/pr_open, mark as failed
      store = Store.new
      item = store.backlog_by_branch(branch)
      if item && %w[running pr_open].include?(item[:status])
        store.update_backlog_status(item[:id], "failed", failure_reason: "manual_close")
        puts "nightshift: backlog item marked failed (manual_close)"
      end

      # Kill tmux window
      renderer = Renderer.new(session: session)
      renderer.close_worktree(branch)

      # Remove worktree
      if wt_path
        system("git", "-C", repo_path, "worktree", "remove", wt_path, "--force")
      end
      puts "nightshift: closed #{branch}"
    end

    def worktree_path_for_branch(_repo_path, branch)
      Worktree.path_for_branch(branch)
    end

    def cmd_auto(_args)
      store = Store.new
      items = store.all_backlog

      pending = items.count { |i| i[:status] == "pending" }
      running = items.count { |i| i[:status] == "running" }
      pr_open = items.count { |i| i[:status] == "pr_open" }
      done = items.count { |i| i[:status] == "done" }
      failed = items.count { |i| i[:status] == "failed" }

      puts ""
      puts "  nightshift auto"
      puts ""
      puts "  backlog: #{pending} pending, #{running} running, #{pr_open} pr_open, #{done} done, #{failed} failed"

      Reconciler::SKILLS.each do |skill|
        active = store.active_for_skill?(skill)
        skill_pending = items.count { |i| i[:skill] == skill && i[:status] == "pending" }
        puts "  #{skill}: #{active ? '🔄 active' : '⬜ idle'} (#{skill_pending} pending)"
      end

      puts ""
      puts "  picking next items..."

      prs = GitHub.fetch_prs
      renderer = Renderer.new
      reconciler = Reconciler.new(store: store, renderer: renderer)
      reconciler.reconcile(prs)

      puts "  entering watch loop..."
      puts ""

      cmd_watch([])
    end

    def cmd_skill_run(args)
      skill = args.shift or abort("Usage: nightshift skill-run <skill> <item>")
      item_path = args.shift or abort("Usage: nightshift skill-run <skill> <item>")
      worktree_path = Dir.pwd
      store = Store.new

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
        return
      end

      # Check pr-description.md
      desc_path = File.join(worktree_path, "pr-description.md")
      unless File.exist?(desc_path)
        store.update_backlog_status(backlog_item[:id], "failed",
                                   failure_reason: "no_pr_description")
        puts "nightshift: skill succeeded but no .nightshift/pr-description.md"
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
      else
        abort "Usage: nightshift backlog <add|scan|list>"
      end
    end

    def cmd_backlog_add(args)
      skill = args.shift or abort("Usage: nightshift backlog add <skill> <item>")
      item = args.shift or abort("Usage: nightshift backlog add <skill> <item>")
      store = Store.new
      store.add_backlog(skill, item)
      puts "nightshift: added #{item} to #{skill} backlog"
    end

    def cmd_backlog_scan(args)
      skill = args.shift or abort("Usage: nightshift backlog scan <skill>")
      repo_path = ENV.fetch("NIGHTSHIFT_REPO")
      store = Store.new

      case skill
      when "haml-migration"
        files = Dir.glob("#{repo_path}/app/views/**/*.html.haml")
        files.each { |f| store.add_backlog(skill, f.sub("#{repo_path}/", "")) }
        puts "nightshift: scanned #{files.size} haml files"
      when "test-optimization"
        files = Dir.glob("#{repo_path}/spec/**/*_spec.rb")
        files.each { |f| store.add_backlog(skill, f.sub("#{repo_path}/", "")) }
        puts "nightshift: scanned #{files.size} spec files"
      else
        abort "nightshift: unknown skill '#{skill}' for scan"
      end
    end

    def cmd_backlog_list(args)
      skill_filter = args.shift
      store = Store.new
      items = store.all_backlog(skill: skill_filter)

      icons = { "pending" => "⬜", "running" => "🔄", "pr_open" => "🔵",
                "done" => "✅", "failed" => "❌" }

      puts ""
      items.each do |item|
        icon = icons[item[:status]] || "?"
        extra = ""
        extra = " PR##{item[:pr_number]}" if item[:pr_number]
        extra += " (#{item[:failure_reason]})" if item[:failure_reason]
        puts "  #{icon} [#{item[:skill]}] #{item[:item]}#{extra}"
      end
      puts ""
      counts = items.group_by { |i| i[:status] }.transform_values(&:size)
      puts "  #{items.size} items: #{counts.map { |k, v| "#{v} #{k}" }.join(", ")}"
      puts ""
    end

    def fallback_bash(cmd, args)
      bash_path = File.join(__dir__, "../../bin/nightshift")
      unless File.exist?(bash_path)
        abort "nightshift: '#{cmd}' not yet implemented in Ruby"
      end
      exec(bash_path, cmd, *args)
    end

    def usage
      puts "Usage: nightshift <#{COMMANDS.join('|')}>"
      exit 1
    end
  end
end
