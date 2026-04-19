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
      send_pane_brief(target, pr)
    end

    def send_pane_brief(target, pr)
      line = pane_brief_line(pr)
      # Set pane title (visible in pane border with pane-border-format)
      system("tmux", "select-pane", "-t", "#{@session}:#{target}", "-T", line)
    end

    def pane_brief_line(pr)
      parts = ["##{pr.number}", pr.badge, pr.slug]
      parts << "by:#{pr.reviewer}" if pr.reviewer && !pr.reviewer.empty?
      parts << pr.updated_at.to_s.slice(0, 10) if pr.updated_at
      parts.compact.join(" ")
    end

    def autofix(pr)
      target = find_window_by_branch(pr.branch, caller_action: "autofix ##{pr.number}")
      return unless target
      system("tmux", "send-keys", "-t", "#{@session}:#{target}",
             "#{BINSTUB} autofix #{pr.number}", "Enter")
    end

    def propose_merge(pr)
      target = find_window_by_branch(pr.branch, caller_action: "propose_merge ##{pr.number}")
      return unless target
      system("tmux", "display-menu", "-t", "#{@session}:#{target}",
             "-T", "PR ##{pr.number} approved",
             "Merge (squash)", "m", "run-shell 'gh pr merge #{pr.number} --auto --squash'",
             "View PR", "v", "run-shell 'gh pr view #{pr.number} --web'",
             "Skip", "s", "")
    end

    def show_comments(pr)
      target = find_window_by_branch(pr.branch, caller_action: "show_comments ##{pr.number}")
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
      target = find_window_by_branch(pr.branch, caller_action: "propose_cleanup ##{pr.number}")
      return unless target
      system("tmux", "display-menu", "-t", "#{@session}:#{target}",
             "-T", "PR ##{pr.number} #{pr.github_state == 'MERGED' ? 'merged' : 'deployed'}",
             "Close worktree", "c", "send-keys -t #{@session}:#{target} '#{BINSTUB} close #{pr.branch}' Enter",
             "Keep", "k", "")
    end

    private

    def find_window_by_branch(branch, caller_action: nil)
      return nil unless branch
      out, _, status = Open3.capture3(
        "tmux", "list-windows", "-t", @session,
        "-F", '#{window_index} #{@branch}'
      )
      unless status.success?
        $stderr.puts "nightshift: tmux session #{@session} not found" if caller_action
        return nil
      end

      out.each_line do |line|
        idx, win_branch = line.strip.split(" ", 2)
        return idx if win_branch == branch
      end
      $stderr.puts "nightshift: window not found for #{branch} (#{caller_action})" if caller_action
      nil
    end
  end
end
