# frozen_string_literal: true

require 'open3'

module Nightshift
  module UI
    class TmuxAdapter
      include Renderer

      # @param mode [:plain, :cc] :plain = standard tmux, :cc = iTerm2 tmux -CC integration
      def initialize(session: ENV.fetch('NIGHTSHIFT_SESSION'), mode: :plain)
        @session = session
        @mode = mode
      end

      # --- Session lifecycle ---

      def session_exists?
        system('tmux', 'has-session', '-t', @session, out: File::NULL, err: File::NULL)
      end

      def create_session(main_path:)
        system('tmux', 'new-session', '-d', '-s', @session, '-n', '📦 main', '-c', main_path)
        system('tmux', 'set-option', '-w', '-t', @session, 'allow-rename', 'off')
        system('tmux', 'set-option', '-t', @session, 'pane-border-status', 'top')
        system('tmux', 'set-option', '-t', @session, 'pane-border-format', ' #{pane_title} ')
      end

      def attach_or_switch
        if ENV['TMUX']
          system('tmux', 'switch-client', '-t', @session)
        elsif @mode == :cc
          system('tmux', '-CC', 'attach', '-t', @session)
        else
          system('tmux', 'attach', '-t', @session)
        end
      end

      # --- Window management ---

      def create_window(name:, path:, branch: nil)
        out, = Open3.capture2('tmux', 'new-window', '-t', @session, '-n', name,
                              '-c', path, '-P', '-F', '#{window_id}')
        win_id = out.strip
        set_window_metadata(window_id: win_id, key: '@branch', value: branch) if branch
        win_id
      end

      def find_window(branch:)
        return nil unless branch

        out, _, status = Open3.capture3(
          'tmux', 'list-windows', '-t', @session,
          '-F', '#{window_id} #{@branch}'
        )
        return nil unless status.success?

        out.each_line do |line|
          win_id, win_branch = line.strip.split(' ', 2)
          return win_id if win_branch == branch
        end
        nil
      end

      def rename_window(window_id:, name:)
        system('tmux', 'rename-window', '-t', window_id, name)
      end

      def close_window(branch:)
        win = find_window(branch: branch)
        return unless win

        system('tmux', 'kill-window', '-t', win)
      end

      def select_main_window
        system('tmux', 'select-window', '-t', "#{@session}:0")
      end

      def set_window_metadata(window_id:, key:, value:)
        system('tmux', 'set-option', '-w', '-t', window_id, key, value)
      end

      # --- Pane operations ---

      def split_pane(window_id:, direction: :vertical, size: '20%', path: nil)
        args = ['tmux', 'split-window', '-t', window_id]
        args += [direction == :vertical ? '-v' : '-h']
        args += ['-l', size]
        args += ['-c', path] if path
        system(*args)
      end

      def set_pane_title(window_id:, title:)
        system('tmux', 'select-pane', '-t', window_id, '-T', title)
      end

      def send_keys(target:, command:)
        system('tmux', 'send-keys', '-t', target, command, 'Enter')
      end

      def focus_pane(target:)
        system('tmux', 'select-pane', '-t', target)
      end

      # --- Display ---

      def notify(target:, message:)
        system('tmux', 'display-message', '-t', target, message)
      end

      def menu(target:, title:, items:)
        args = ['tmux', 'display-menu', '-t', target, '-T', title]
        items.each do |item|
          args += [item[:label], item[:key], item[:command]]
        end
        system(*args)
      end

      # --- Post-attach menus ---

      def on_post_attach(approved_prs:, cleanup_prs:, session:)
        require 'shellwords'
        hook_dir = File.join(Dir.home, '.nightshift')
        FileUtils.mkdir_p(hook_dir)
        hook_script = File.join(hook_dir, 'attach_hook.sh')

        lines = ['#!/bin/bash', 'sleep 1']

        if approved_prs.any?
          menu_args = approved_prs.map do |pr|
            label = Shellwords.escape("✅ ##{pr[:number]} #{pr[:slug]}")
            cmd = Shellwords.escape("#{Nightshift.binstub_cmd} pr merge #{pr[:number]}")
            "#{label} #{pr[:number]} \"run-shell #{cmd}\""
          end.join(' ')
          menu_args += " '' '' '' 'ignorer' q ''"
          lines << "tmux display-menu -T ' PRs à merger ' #{menu_args}"
        end

        cleanup_prs.each do |pr|
          emoji = pr[:deployed] ? '🚀' : '🗑'
          target = Shellwords.escape("#{session}:#{pr[:win_id]}")
          lines << "tmux display-menu -t #{target} -T '#{emoji} ##{pr[:number]} #{pr[:slug]}' " \
                   "'Fermer worktree' c \"send-keys -t #{target} '#{Nightshift.binstub_cmd} worktree close #{pr[:branch]}' Enter\" " \
                   "'Garder' k ''"
        end

        escaped_session = Shellwords.escape(session)
        lines << "tmux set-hook -u -t #{escaped_session} client-attached"

        File.write(hook_script, "#{lines.join("\n")}\n")
        File.chmod(0o755, hook_script)
        system('tmux', 'set-hook', '-t', @session, 'client-attached', "run-shell '#{hook_script}'")
      end
    end
  end
end
