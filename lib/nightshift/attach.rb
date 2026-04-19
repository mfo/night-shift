require "open3"

module Nightshift
  module Attach
    BINSTUB = File.expand_path("../../bin/nightshift-rb", __dir__).freeze

    module_function

    def run
      repo_path = ENV.fetch("NIGHTSHIFT_REPO")
      session = ENV.fetch("NIGHTSHIFT_SESSION")

      unless system("command", "-v", "tmux", out: File::NULL, err: File::NULL)
        abort "error: tmux not installed"
      end

      unless File.directory?(File.join(repo_path, ".git")) || File.exist?(File.join(repo_path, ".git"))
        abort "error: #{repo_path} is not a git repo"
      end

      # If session exists, just attach
      if system("tmux", "has-session", "-t", session, out: File::NULL, err: File::NULL)
        reattach(session, repo_path)
        return
      end

      puts ""
      puts "  nightshift"
      puts ""

      # Count worktrees
      worktrees = Worktree.list(repo_path)
      puts "  ◎ #{worktrees.size} worktrees found"

      # Fetch PRs
      puts "  ◎ fetching PRs from GitHub ..."
      store = Store.new
      begin
        prs = GitHub.fetch_prs
        prs.each { |pr| store.reconcile_pr(pr) }
        open_count = prs.count { |pr| pr.github_state == "OPEN" }
        puts "  ✓ #{open_count} open PRs"
      rescue GitHub::Error => e
        $stderr.puts "  ⚠ #{e.message}"
        prs = store.all_prs.map { |r| PR.from_db(r) }
        puts "  ⚠ using cached PRs (#{prs.size})"
      end

      # Build PR lookup by branch
      pr_by_branch = prs.each_with_object({}) { |pr, h| h[pr.branch] = pr }

      # Create session with main window
      puts "  ◎ building tmux session ..."
      main_path = Worktree.main_path(repo_path)
      system("tmux", "new-session", "-d", "-s", session, "-n", "📦 main", "-c", main_path)
      system("tmux", "set-option", "-w", "-t", session, "allow-rename", "off")
      # Show pane titles in border (brief per pane)
      system("tmux", "set-option", "-t", session, "pane-border-status", "top")
      system("tmux", "set-option", "-t", session, "pane-border-format", ' #{pane_title} ')

      n_red = 0
      n_green = 0
      n_running = 0
      n_approved = 0
      approved_prs = []
      cleanup_prs = []

      worktrees.each do |wt_path, wt_branch|
        pr = pr_by_branch[wt_branch]
        name = pr ? pr.window_name : "🔨 #{wt_branch}"

        system("tmux", "new-window", "-t", session, "-n", name, "-c", wt_path)

        # Store metadata in tmux window options
        out, = Open3.capture2("tmux", "list-windows", "-t", session, "-F", '#{window_index}')
        win_idx = out.lines.last&.strip
        system("tmux", "set-option", "-w", "-t", "#{session}:#{win_idx}", "@worktree_path", wt_path)
        system("tmux", "set-option", "-w", "-t", "#{session}:#{win_idx}", "@branch", wt_branch)

        # Set pane title with PR brief
        if pr
          pane_brief = "##{pr.number} #{pr.badge} #{pr.slug}"
          pane_brief += " by:#{pr.reviewer}" if pr.reviewer && !pr.reviewer.to_s.empty?
          system("tmux", "select-pane", "-t", "#{session}:#{win_idx}", "-T", pane_brief)
        else
          system("tmux", "select-pane", "-t", "#{session}:#{win_idx}", "-T", wt_branch)
        end

        if pr
          case pr.ci
          when "red" then n_red += 1
          when "green" then n_green += 1
          when "running" then n_running += 1
          end

          # Auto-actions
          if pr.ci == "red" && pr.github_state == "OPEN"
            system("tmux", "send-keys", "-t", "#{session}:#{win_idx}",
                   "#{BINSTUB} autofix #{pr.number}", "Enter")
          elsif pr.review_decision == "APPROVED" && pr.github_state == "OPEN" && !pr.auto_merge
            n_approved += 1
            approved_prs << { number: pr.number, branch: wt_branch, slug: pr.slug, win_idx: win_idx }
          elsif %w[CHANGES_REQUESTED].include?(pr.review_decision) || pr.review_count.to_i > 0
            system("tmux", "send-keys", "-t", "#{session}:#{win_idx}",
                   "gh pr view #{pr.number} --comments", "Enter")
          end

          # Collect cleanup candidates (menu shown post-attach via hook)
          if %w[MERGED].include?(pr.github_state)
            cleanup_prs << { number: pr.number, branch: wt_branch, slug: pr.slug, deployed: pr.deployed, win_idx: win_idx }
          end
        end

        puts "    #{name}"
      end

      out, = Open3.capture2("tmux", "list-windows", "-t", session)
      win_count = out.lines.size.to_s
      status_parts = ""
      status_parts += " #{n_approved}✅" if n_approved > 0
      status_parts += " #{n_green}🟢" if n_green > 0
      status_parts += " #{n_red}🔴" if n_red > 0
      status_parts += " #{n_running}⏳" if n_running > 0

      puts ""
      puts "  ✓ #{win_count} windows ready#{status_parts}"
      puts "  ◎ autofix queued for #{n_red} red PR(s)" if n_red > 0
      puts "  ◎ merge proposed for #{n_approved} approved PR(s)" if n_approved > 0
      puts "  ◎ #{cleanup_prs.size} worktree(s) to cleanup" if cleanup_prs.any?
      puts "  ◎ launching morning brief ..."
      puts ""

      # Queue menus for after client attaches (display-menu needs active client)
      if approved_prs.any? || cleanup_prs.any?
        setup_post_attach_hook(session, approved_prs, cleanup_prs)
      end

      # Launch brief + auto (skill picking + watch) in main window
      system("tmux", "send-keys", "-t", "#{session}:0",
             "#{BINSTUB} brief && #{BINSTUB} auto", "Enter")

      # Select main window and attach
      system("tmux", "select-window", "-t", "#{session}:0")
      if ENV["TMUX"]
        system("tmux", "switch-client", "-t", session)
      else
        system("tmux", "attach", "-t", session)
      end
    end

    def reattach(session, repo_path)
      # Show teaser if last brief was > 4h ago
      store = Store.new
      last_brief = store.get_setting("last_brief")
      if last_brief.nil? || (Time.now.to_i - last_brief.to_i) > 14400
        puts "nightshift: brief outdated, run '#{BINSTUB} brief'"
      end

      puts "nightshift: session exists, attaching (use 'refresh' to update)"
      if ENV["TMUX"]
        system("tmux", "switch-client", "-t", session)
      else
        system("tmux", "attach", "-t", session)
      end
    end

    def setup_post_attach_hook(session, approved_prs, cleanup_prs)
      require "shellwords"
      hook_dir = File.join(Dir.home, ".nightshift")
      FileUtils.mkdir_p(hook_dir)
      hook_script = File.join(hook_dir, "attach_hook.sh")

      lines = ["#!/bin/bash", "sleep 1"]

      if approved_prs.any?
        menu_args = approved_prs.map do |pr|
          label = Shellwords.escape("✅ ##{pr[:number]} #{pr[:slug]}")
          cmd = Shellwords.escape("#{BINSTUB} merge #{pr[:number]}")
          "#{label} #{pr[:number]} \"run-shell #{cmd}\""
        end.join(" ")
        menu_args += " '' '' '' 'ignorer' q ''"
        lines << "tmux display-menu -T ' PRs à merger ' #{menu_args}"
      end

      # One popup per cleanup PR, targeted at its own pane
      cleanup_prs.each do |pr|
        emoji = pr[:deployed] ? "🚀" : "🗑"
        target = Shellwords.escape("#{session}:#{pr[:win_idx]}")
        close_cmd = Shellwords.escape("#{BINSTUB} close #{pr[:branch]}")
        lines << "tmux display-menu -t #{target} -T '#{emoji} ##{pr[:number]} #{pr[:slug]}' " \
                 "'Fermer worktree' c \"send-keys -t #{target} '#{BINSTUB} close #{pr[:branch]}' Enter\" " \
                 "'Garder' k ''"
      end

      escaped_session = Shellwords.escape(session)
      lines << "tmux set-hook -u -t #{escaped_session} client-attached"

      File.write(hook_script, lines.join("\n") + "\n")
      File.chmod(0o755, hook_script)
      system("tmux", "set-hook", "-t", session, "client-attached", "run-shell '#{hook_script}'")
    end
  end
end
