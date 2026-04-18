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

    def notify_fixed(pr)
      target = find_window_by_branch(pr.branch)
      return unless target
      system("tmux", "display-message", "-t", "#{@session}:#{target}",
             "CI fixed on ##{pr.number} ✅")
    end

    def create_window(branch, path)
      system("tmux", "new-window", "-t", @session,
             "-n", "🔨 #{branch}", "-c", path)
      # Store branch in tmux window option for lookup
      system("tmux", "set-window-option", "-t", "#{@session}:",
             "@branch", branch)
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
