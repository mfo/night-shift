require "open3"
require "set"

module Nightshift
  class Reconciler
    def initialize(store:, renderer:, worktree_branches: nil)
      @store = store
      @renderer = renderer
      @worktree_branches = worktree_branches
    end

    SKILLS = Nightshift::SKILLS

    def reconcile(prs)
      # Worktree-centric: only reconcile PRs that match a local worktree
      branches = @worktree_branches || list_worktree_branches
      active_prs = prs.select { |pr| branches.include?(pr.branch) }

      active_prs.each do |pr|
        result = @store.reconcile_pr(pr)
        if result[:changed] && !@store.locked?(pr.number, kind: result[:new_state].to_s)
          on_transition(pr, result[:old_state], result[:new_state])
        end
        @renderer.update_window(pr)
      end
      reconcile_skills(active_prs)
    end

    def reconcile_skills(prs)
      pr_by_branch = prs.each_with_object({}) { |pr, h| h[pr.branch] = pr }
      active_branches = @worktree_branches || list_worktree_branches

      @store.all_backlog.each do |item|
        case item[:status]
        when "pr_open"
          pr = pr_by_branch[item[:branch]]
          handle_done(item) if pr&.github_state == "MERGED"
        when "running"
          # Zombie recovery: running item but worktree gone
          if item[:branch] && !active_branches.include?(item[:branch])
            @store.update_backlog_status(item[:id], "failed",
                                         failure_reason: "zombie_recovered")
          end
        end
      end

      pick_next_items
    end

    private

    def handle_done(item)
      @store.update_backlog_status(item[:id], "done")
      Worktree.cleanup(item[:branch])
      @renderer.close_worktree(item[:branch])
    end

    def pick_next_items
      repo_path = ENV.fetch("NIGHTSHIFT_REPO")
      SKILLS.each_key do |skill_name|
        next if @store.active_for_skill?(skill_name)
        item = @store.claim_next(skill_name)
        next unless item

        # Guard: skip if the target file no longer exists on main
        unless system("git", "-C", repo_path, "cat-file", "-e", "HEAD:#{item[:item]}", err: File::NULL)
          @store.update_backlog_status(item[:id], "skipped", failure_reason: "file_not_found")
          next
        end

        launch_skill(skill_name, item)
      end
    end

    def launch_skill(skill_name, item)
      require "shellwords"
      repo_path = ENV.fetch("NIGHTSHIFT_REPO")
      slug = short_slug(item[:item])
      branch = "auto/#{skill_name}/#{slug}"
      wt_dir = "auto-#{skill_name}-#{slug}"
      wt_path = File.join(File.dirname(repo_path), wt_dir)

      # Clean up stale branch/dir from previous failed attempts
      Worktree.cleanup(branch)

      unless system("git", "-C", repo_path, "worktree", "add", wt_path, "main", "-b", branch)
        @store.update_backlog_status(item[:id], "failed", failure_reason: "worktree_error")
        return
      end
      @store.update_backlog_status(item[:id], "running", branch: branch)

      session = ENV.fetch("NIGHTSHIFT_SESSION")
      skill_config = SKILLS[skill_name] || {}

      # Allocate port for skills that need a local server
      port = nil
      if skill_config[:needs_server]
        port = allocate_port
        setup_worktree_server(wt_path, repo_path, port)
      end

      system("tmux", "new-window", "-t", session, "-n", "🤖 #{skill_name}", "-c", wt_path)

      # Get the window index of the just-created window and tag it
      out, = Open3.capture2("tmux", "list-windows", "-t", session, "-F", '#{window_index}')
      win_idx = out.lines.last&.strip
      system("tmux", "set-option", "-w", "-t", "#{session}:#{win_idx}", "@branch", branch)

      # Launch server in background pane if needed
      if port
        system("tmux", "split-window", "-t", "#{session}:#{win_idx}", "-v", "-l", "20%",
               "-c", wt_path)
        system("tmux", "send-keys", "-t", "#{session}:#{win_idx}.1",
               "overmind start -f Procfile.sidekiq.dev", "Enter")
        # Wait for server to be ready, then run skill in main pane
        system("tmux", "select-pane", "-t", "#{session}:#{win_idx}.0")
      end

      # Send skill-run command
      binstub = File.expand_path("../../bin/nightshift-rb", __dir__)
      env_prefix = port ? "NIGHTSHIFT_PORT=#{port}" : ""
      cmd = "#{env_prefix} #{binstub} skill-run #{skill_name} #{Shellwords.escape(item[:item])}".strip
      system("tmux", "send-keys", "-t", "#{session}:#{win_idx}.0", cmd, "Enter")
    end

    def allocate_port
      # Find next available port based on active running skills
      used_ports = @store.all_backlog.select { |i| i[:status] == "running" }.size
      Nightshift::BASE_PORT + used_ports
    end

    def setup_worktree_server(wt_path, _repo_path, port)
      vite_port = port + 100

      # .env.development.local — overrides PORT for rails + vite
      env_dev = File.join(wt_path, ".env.development.local")
      File.write(env_dev, <<~ENV)
        PORT=#{port}
        VITE_RUBY_PORT=#{vite_port}
        APP_HOST=localhost:#{port}
      ENV
    end

    def list_worktree_branches
      Worktree.branches
    end

    # Fuzzy-readable slug: dir initials + filename
    # spec/system/routing/rules_full_scenario_spec.rb → s-s-r-rules_full_scenario
    # app/views/shared/dossiers/_demande.html.haml → v-s-d-_demande
    def short_slug(path)
      parts = path.sub(%r{^(app|spec)/}, "").split("/")
      filename = parts.pop
      filename = filename.sub(/(_spec)?\.rb$/, "").sub(/\.html\.haml$/, "")
      dirs = parts.map { |d| d[0] }
      (dirs + [filename]).join("-")
    end

    def on_transition(pr, old_state, new_state)
      case [old_state, new_state]
      in [_, :ci_red]
        @renderer.autofix(pr)
      in [_, :approved]
        @renderer.propose_merge(pr)
      in [_, :has_comments | :changes_requested]
        @renderer.show_comments(pr)
      in [:ci_red, :ci_green]
        @renderer.notify_fixed(pr)
      in [_, :merged | :deployed]
        @renderer.propose_cleanup(pr)
      else
        # noop
      end
    end
  end
end
