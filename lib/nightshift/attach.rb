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
      worktrees = list_worktrees(repo_path)
      puts "  ◎ #{worktrees.size} worktrees found"

      # Fetch PRs
      puts "  ◎ fetching PRs from GitHub ..."
      store = Store.new
      prs = GitHub.fetch_prs
      prs.each { |pr| store.reconcile_pr(pr) }
      open_count = prs.count { |pr| pr.github_state == "OPEN" }
      puts "  ✓ #{open_count} open PRs"

      # Build PR lookup by branch
      pr_by_branch = prs.each_with_object({}) { |pr, h| h[pr.branch] = pr }

      # Create session with main window
      puts "  ◎ building tmux session ..."
      main_path = git_main_worktree(repo_path)
      system("tmux", "new-session", "-d", "-s", session, "-n", "📦 main", "-c", main_path)
      system("tmux", "set-option", "-w", "-t", session, "allow-rename", "off")

      n_red = 0
      n_green = 0
      n_running = 0
      n_approved = 0
      approved_prs = []

      worktrees.each do |wt_path, wt_branch|
        pr = pr_by_branch[wt_branch]
        name = pr ? pr.window_name : "🔨 #{wt_branch}"

        system("tmux", "new-window", "-t", session, "-n", name, "-c", wt_path)

        # Store metadata in tmux window options
        out, = Open3.capture2("tmux", "list-windows", "-t", session, "-F", '#{window_index}')
        win_idx = out.lines.last&.strip
        system("tmux", "set-option", "-w", "-t", "#{session}:#{win_idx}", "@worktree_path", wt_path)
        system("tmux", "set-option", "-w", "-t", "#{session}:#{win_idx}", "@branch", wt_branch)

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
      puts "  ◎ launching morning brief ..."
      puts ""

      # Queue merge menu for approved PRs
      if approved_prs.any?
        setup_merge_hook(session, approved_prs)
      end

      # Launch brief then watch in main window
      system("tmux", "send-keys", "-t", "#{session}:0",
             "#{BINSTUB} brief && #{BINSTUB} watch", "Enter")

      # Attach
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

    def list_worktrees(repo_path)
      output, = Open3.capture2("git", "-C", repo_path, "worktree", "list")
      lines = output.lines.drop(1) # skip main
      lines.filter_map do |line|
        wt_path = line.split.first
        wt_path = wt_path.sub(/^~/, Dir.home)
        branch_match = line.match(/\[(.+)\]/)
        next unless branch_match
        branch = branch_match[1]
        next unless File.directory?(wt_path)
        [wt_path, branch]
      end
    end

    def git_main_worktree(repo_path)
      output, = Open3.capture2("git", "-C", repo_path, "worktree", "list")
      path = output.lines.first&.split&.first
      path&.sub(/^~/, Dir.home) || repo_path
    end

    def setup_merge_hook(session, approved_prs)
      require "shellwords"
      hook_dir = File.join(Dir.home, ".nightshift")
      FileUtils.mkdir_p(hook_dir)
      hook_script = File.join(hook_dir, "attach_hook.sh")

      menu_args = approved_prs.map do |pr|
        label = Shellwords.escape("✅ ##{pr[:number]} #{pr[:slug]}")
        cmd = Shellwords.escape("#{BINSTUB} merge #{pr[:number]}")
        "#{label} #{pr[:number]} \"run-shell #{cmd}\""
      end.join(" ")
      menu_args += " '' '' '' 'ignorer' q ''"

      escaped_session = Shellwords.escape(session)
      File.write(hook_script, <<~BASH)
        #!/bin/bash
        sleep 1
        tmux display-menu -T ' PRs à merger ' #{menu_args}
        tmux set-hook -u -t #{escaped_session} client-attached
      BASH
      File.chmod(0o755, hook_script)
      system("tmux", "set-hook", "-t", session, "client-attached", "run-shell '#{hook_script}'")
    end
  end
end
