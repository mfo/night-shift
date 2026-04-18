module Nightshift
  class Reconciler
    def initialize(store:, renderer:)
      @store = store
      @renderer = renderer
    end

    SKILLS = %w[haml-migration test-optimization].freeze

    def reconcile(prs)
      prs.each do |pr|
        result = @store.reconcile_pr(pr)
        if result[:changed] && !@store.locked?(pr.number, kind: result[:new_state].to_s)
          on_transition(pr, result[:old_state], result[:new_state])
        end
        @renderer.update_window(pr)
      end
      reconcile_skills(prs)
    end

    def reconcile_skills(prs)
      pr_by_branch = prs.each_with_object({}) { |pr, h| h[pr.branch] = pr }

      @store.all_backlog.select { |i| i[:status] == "pr_open" }.each do |item|
        pr = pr_by_branch[item[:branch]]
        handle_done(item) if pr&.github_state == "MERGED"
      end

      pick_next_items
    end

    private

    def handle_done(item)
      @store.update_backlog_status(item[:id], "done")
      repo_path = ENV.fetch("NIGHTSHIFT_REPO")
      wt_path = File.join(File.dirname(repo_path), item[:branch])
      system("git", "-C", repo_path, "worktree", "remove", wt_path, "--force")
      @renderer.close_worktree(item[:branch])
    end

    def pick_next_items
      SKILLS.each do |skill_name|
        next if @store.active_for_skill?(skill_name)
        item = @store.claim_next(skill_name)
        next unless item
        launch_skill(skill_name, item)
      end
    end

    def launch_skill(skill_name, item)
      require "shellwords"
      repo_path = ENV.fetch("NIGHTSHIFT_REPO")
      slug = item[:item].sub(%r{^app/}, "").gsub("/", "-").sub(/\.html\.haml$/, "").sub(/\.rb$/, "")
      branch = "auto/#{skill_name}/#{slug}"
      wt_path = File.join(File.dirname(repo_path), branch)

      system("git", "-C", repo_path, "worktree", "add", wt_path, "main", "-b", branch)
      @store.update_backlog_status(item[:id], "running", branch: branch)

      session = ENV.fetch("NIGHTSHIFT_SESSION")
      system("tmux", "new-window", "-t", session, "-n", "🤖 #{skill_name}", "-c", wt_path)

      binstub = File.expand_path("../../bin/nightshift-rb", __dir__)
      @renderer.run_in_window(branch, "#{binstub} skill-run #{skill_name} #{Shellwords.escape(item[:item])}")
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
      else
        # noop
      end
    end
  end
end
