# frozen_string_literal: true
# typed: false

#
# CLI::Worktree — Gestion des git worktrees et fenêtres tmux
#
# Chaque worktree = une branche isolée + une fenêtre tmux dédiée.
# Le reconciler crée les worktrees automatiquement pour les skills,
# ces commandes sont pour l'usage manuel.
#
#   open  — Crée un worktree + fenêtre tmux pour une branche
#   close — Supprime worktree + branche + fenêtre tmux
#   reset — Remet les items running/failed d'un skill en pending (cleanup)
#
# Usage :
#   nightshift worktree open feat/my-branch
#   nightshift worktree close feat/my-branch
#   nightshift worktree reset haml-migration

module Nightshift
  class CLI
    class Worktree < Thor
      def self.exit_on_failure? = true

      desc 'open BRANCH', 'Open a new worktree and tmux window'
      def open(branch)
        repo_path = Nightshift.repo_path
        session = ENV.fetch('NIGHTSHIFT_SESSION')
        wt_path = File.join(File.dirname(repo_path), branch)

        unless system('git', '-C', repo_path, 'worktree', 'add', wt_path, 'main', '-b', branch)
          abort "nightshift: failed to create worktree #{branch}"
        end

        system('tmux', 'new-window', '-t', session, '-n', "\u{1f528} #{branch}", '-c', wt_path)
        say_status :open, branch, :green
      end

      desc 'close BRANCH', 'Close a worktree and tmux window'
      def close(branch)
        session = ENV.fetch('NIGHTSHIFT_SESSION')

        item = store.backlog_by_branch(branch)
        if item && [BacklogStatus::Running, BacklogStatus::PrOpen].include?(item.status)
          store.update_backlog_status(item.id, BacklogStatus::Failed, failure_reason: FailureReason::ManualClose.serialize)
          say_status :close, "backlog item marked failed (manual_close)", :yellow
        end

        Integrations::Worktree.cleanup(branch)
        say_status :close, branch, :green

        renderer = UI::TmuxRenderer.new(session: session)
        renderer.close_worktree(branch)
      end

      desc 'reset SKILL', 'Reset running/failed backlog items for a skill'
      def reset(skill)
        session = ENV.fetch('NIGHTSHIFT_SESSION')
        renderer = UI::TmuxRenderer.new(session: session)

        items = store.all_backlog(skill: skill).select do |i|
          [BacklogStatus::Running, BacklogStatus::Failed].include?(i.status) || (i.status == BacklogStatus::Pending && i.branch)
        end
        if items.empty?
          say_status :reset, "nothing to reset for #{skill}", :yellow
          return
        end

        items.each do |item|
          if item.branch
            renderer.close_worktree(item.branch)
            Integrations::Worktree.cleanup(item.branch)
          end
          store.update_backlog_status(item.id, BacklogStatus::Pending, branch: nil, failure_reason: nil)
          say "  \u2b1c ##{item.id} #{item.item} \u2192 pending"
        end
        say_status :reset, "#{items.size} item(s) for #{skill}", :green
      end

      private

      def store = CLI.store
    end
  end
end
