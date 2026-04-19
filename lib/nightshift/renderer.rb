require "open3"

module Nightshift
  class Renderer
    BINSTUB = File.expand_path("../../bin/nightshift-rb", __dir__).freeze

    def initialize(session: ENV.fetch("NIGHTSHIFT_SESSION"))
      @session = session
    end

    def update_window(pr)
      target = find_window_by_branch(pr.branch)
      return unless target
      system("tmux", "rename-window", "-t", "#{@session}:#{target}", pr.window_name)
    end

    def autofix(pr)
      target = find_window_by_branch(pr.branch)
      return unless target
      system("tmux", "send-keys", "-t", "#{@session}:#{target}",
             "#{BINSTUB} autofix #{pr.number}", "Enter")
    end

    def propose_merge(pr)
      target = find_window_by_branch(pr.branch)
      return unless target
      system("tmux", "display-menu", "-t", "#{@session}:#{target}",
             "-T", "PR ##{pr.number} approved",
             "Merge (squash)", "m", "run-shell 'gh pr merge #{pr.number} --auto --squash'",
             "View PR", "v", "run-shell 'gh pr view #{pr.number} --web'",
             "Skip", "s", "")
    end

    def show_comments(pr)
      target = find_window_by_branch(pr.branch)
      return unless target
      system("tmux", "send-keys", "-t", "#{@session}:#{target}",
             "gh pr view #{pr.number} --comments", "Enter")
    end

    def run_in_window(branch, command)
      target = find_window_by_branch(branch)
      return unless target
      system("tmux", "send-keys", "-t", "#{@session}:#{target}",
             command, "Enter")
    end

    def close_worktree(branch)
      target = find_window_by_branch(branch)
      return unless target
      system("tmux", "kill-window", "-t", "#{@session}:#{target}")
    end

    def notify_fixed(pr)
      target = find_window_by_branch(pr.branch)
      return unless target
      system("tmux", "display-message", "-t", "#{@session}:#{target}",
             "CI fixed on ##{pr.number} ✅")
    end

    def propose_cleanup(pr)
      target = find_window_by_branch(pr.branch)
      return unless target
      system("tmux", "display-menu", "-t", "#{@session}:#{target}",
             "-T", "PR ##{pr.number} #{pr.github_state == 'MERGED' ? 'merged' : 'deployed'}",
             "Close worktree", "c", "run-shell '#{BINSTUB} close #{pr.branch}'",
             "Keep", "k", "")
    end

    private

    def find_window_by_branch(branch)
      return nil unless branch
      out, _, status = Open3.capture3(
        "tmux", "list-windows", "-t", @session,
        "-F", '#{window_index} #{@branch}'
      )
      return nil unless status.success?

      out.each_line do |line|
        idx, win_branch = line.strip.split(" ", 2)
        return idx if win_branch == branch
      end
      nil
    end
  end
end
