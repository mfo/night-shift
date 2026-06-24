# frozen_string_literal: true

module Nightshift
  module UI
    #
    # Renderer — Abstract interface for terminal multiplexer adapters
    #
    # All window/pane/session management goes through this interface.
    # Implementations: TmuxAdapter, (future) Iterm2Adapter.
    #
    module Renderer
      # --- Session lifecycle ---

      # @return [Boolean]
      def session_exists? = raise NotImplementedError

      # @param main_path [String] working directory for the main window
      def create_session(main_path:) = raise NotImplementedError

      # Attach or switch to the session (blocks until detach)
      def attach_or_switch = raise NotImplementedError

      # --- Window management ---

      # @param name [String] window title
      # @param path [String] working directory
      # @param branch [String] branch metadata stored on the window
      # @return [String] window identifier
      def create_window(name:, path:, branch: nil) = raise NotImplementedError

      # @return [String, nil] window identifier or nil
      def find_window(branch:) = raise NotImplementedError

      def rename_window(window_id:, name:) = raise NotImplementedError
      def close_window(branch:) = raise NotImplementedError
      def select_main_window = raise NotImplementedError

      # Store arbitrary key/value metadata on a window
      def set_window_metadata(window_id:, key:, value:) = raise NotImplementedError

      # --- Pane operations ---

      # @param size [String] e.g. '20%'
      # @return [String] pane identifier
      def split_pane(window_id:, direction: :vertical, size: '20%', path: nil) = raise NotImplementedError

      def set_pane_title(window_id:, title:) = raise NotImplementedError
      def send_keys(target:, command:) = raise NotImplementedError
      def focus_pane(target:) = raise NotImplementedError

      # --- Display ---

      def notify(target:, message:) = raise NotImplementedError

      # @param items [Array<Hash>] each: { label:, key:, command: }
      def menu(target:, title:, items:) = raise NotImplementedError

      # --- Hooks ---

      # Show menus for approved/cleanup PRs after session is ready.
      # Called by Attach once all windows are created.
      # @param approved_prs [Array<Hash>] each: { number:, branch:, slug:, win_id: }
      # @param cleanup_prs [Array<Hash>] each: { number:, branch:, slug:, deployed:, win_id: }
      # @param session [String] session name
      def on_post_attach(approved_prs:, cleanup_prs:, session:) = raise NotImplementedError

      # --- Domain helpers (shared across adapters) ---

      def pane_brief_line(pr)
        parts = ["##{pr.number}", pr.badge, pr.slug]
        parts << "💬#{pr.comment_count}" if pr.comment_count.to_i.positive?
        parts << "by:#{pr.reviewer}" if pr.reviewer && !pr.reviewer.empty?
        parts << pr.updated_at.to_s.slice(0, 10) if pr.updated_at
        parts.compact.join(' ')
      end

      def update_window(pr)
        win = find_window(branch: pr.branch)
        return unless win

        rename_window(window_id: win, name: pr.window_name)
        set_pane_title(window_id: win, title: pane_brief_line(pr))
      end

      def autofix(pr)
        win = find_window(branch: pr.branch)
        return unless win

        send_keys(target: "#{win}.0", command: "#{Nightshift.binstub_cmd} pr autofix #{pr.number}")
      end

      def propose_merge(pr)
        win = find_window(branch: pr.branch)
        return unless win

        menu(target: win, title: "PR ##{pr.number} approved", items: [
          { label: 'Merge (squash)', key: 'm', command: "run-shell 'gh pr merge #{pr.number} --auto --squash'" },
          { label: 'View PR', key: 'v', command: "run-shell 'gh pr view #{pr.number} --web'" },
          { label: 'Skip', key: 's', command: '' }
        ])
      end

      def show_comments(pr)
        win = find_window(branch: pr.branch)
        return unless win

        send_keys(target: "#{win}.0", command: "gh pr view #{pr.number} --comments")
      end

      def run_in_window(branch, command)
        win = find_window(branch: branch)
        return unless win

        send_keys(target: "#{win}.0", command: command)
      end

      def close_worktree(branch)
        close_window(branch: branch)
      end

      def notify_fixed(pr)
        win = find_window(branch: pr.branch)
        return unless win

        notify(target: win, message: "CI fixed on ##{pr.number} ✅")
      end

      def propose_cleanup(pr)
        win = find_window(branch: pr.branch)
        return unless win

        menu(target: win, title: "PR ##{pr.number} #{pr.github_state == 'MERGED' ? 'merged' : 'deployed'}", items: [
          { label: 'Close worktree', key: 'c',
            command: "send-keys -t #{win} '#{Nightshift.binstub_cmd} worktree close #{pr.branch}' Enter" },
          { label: 'Keep', key: 'k', command: '' }
        ])
      end

      # Launch a skill/batch window with optional server pane
      # @return [String] window identifier
      def launch_skill_window(name:, path:, branch:, server_cmd: nil, server_size: '20%')
        win = find_window(branch: branch) || create_window(name: name, path: path, branch: branch)

        if server_cmd
          split_pane(window_id: win, direction: :vertical, size: server_size, path: path)
          send_keys(target: "#{win}.1", command: server_cmd)
          focus_pane(target: "#{win}.0")
        end

        win
      end
    end
  end
end
