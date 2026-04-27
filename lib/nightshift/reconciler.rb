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

        # 1. Comments FIRST — show if new comments detected
        if result[:comment_delta] > 0
          @renderer.show_comments(pr)
        end

        # 2. State transitions SECOND
        if result[:changed] && !@store.locked?(pr.number, kind: result[:new_state].to_s)
          on_transition(pr, result[:old_state], result[:new_state])
        end

        # 3. Window update LAST
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
      slug = short_slug(item[:item], skill_name: skill_name)
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

      # Reuse existing window if one already has this branch (e.g. from attach)
      win_id = find_window_by_branch(session, branch)
      unless win_id
        win_id, = Open3.capture2("tmux", "new-window", "-t", session, "-n", "🤖 #{skill_name}-#{slug}",
                                 "-c", wt_path, "-P", "-F", '#{window_id}')
        win_id = win_id.strip
        system("tmux", "set-option", "-w", "-t", win_id, "@branch", branch)
      end

      # Launch server in background pane if skill needs it
      port = skill_config[:port]
      if skill_config[:needs_server] && port
        File.write(File.join(wt_path, ".overmind.env"), "PORT=#{port}\n")
        system("tmux", "split-window", "-t", win_id, "-v", "-l", "20%",
               "-c", wt_path)
        system("tmux", "send-keys", "-t", "#{win_id}.1",
               "overmind start -f Procfile.sidekiq.dev", "Enter")
        system("tmux", "select-pane", "-t", "#{win_id}.0")
      end

      # Send skill-run command
      binstub = File.expand_path("../../bin/nightshift-rb", __dir__)
      env_prefix = port ? "PORT=#{port}" : ""
      cmd = "#{env_prefix} #{binstub} skill-run #{skill_name} #{Shellwords.escape(item[:item])}".strip
      system("tmux", "send-keys", "-t", "#{win_id}.0", cmd, "Enter")
    end

    def find_window_by_branch(session, branch)
      return nil unless branch
      out, _, status = Open3.capture3(
        "tmux", "list-windows", "-t", session,
        "-F", '#{window_id} #{@branch}'
      )
      return nil unless status.success?

      out.each_line do |line|
        win_id, win_branch = line.strip.split(" ", 2)
        return win_id if win_branch == branch
      end
      nil
    end

    def list_worktree_branches
      Worktree.branches
    end

    def short_slug(path, skill_name: nil)
      Nightshift.short_slug(path, skill_name: skill_name)
    end

    def on_transition(pr, old_state, new_state)
      case [old_state, new_state]
      in [_, :ci_red]
        @renderer.autofix(pr)
      in [_, :approved]
        @renderer.propose_merge(pr)
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
