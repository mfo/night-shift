# frozen_string_literal: true
# typed: false

#
# CLI::Worktree — Gestion des git worktrees et fenêtres multiplexer
#
# Chaque worktree = une branche isolée + une fenêtre dédiée.
# Le reconciler crée les worktrees automatiquement pour les skills,
# ces commandes sont pour l'usage manuel.
#
#   open  — Crée un worktree + fenêtre pour une branche
#   close — Supprime worktree + branche + fenêtre
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

      desc 'open BRANCH', 'Open a new worktree and window'
      def open(branch)
        repo_path = Nightshift.repo_path
        wt_path = File.join(File.dirname(repo_path), branch)

        unless system('git', '-C', repo_path, 'worktree', 'add', wt_path, 'main', '-b', branch)
          abort "nightshift: failed to create worktree #{branch}"
        end

        renderer.create_window(name: "🔨 #{branch}", path: wt_path, branch: branch)
        say_status :open, branch, :green
      end

      desc 'close BRANCH', 'Close a worktree and window'
      def close(branch)
        backlog_item = store.backlog_by_branch(branch)
        if backlog_item && [BacklogStatus::Running, BacklogStatus::PrOpen].include?(backlog_item.status)
          store.update_backlog_status(backlog_item, BacklogStatus::Failed, failure_reason: FailureReason::ManualClose)
          say_status :close, "backlog item marked failed (manual_close)", :yellow
        end

        Integrations::Worktree.cleanup(branch)
        say_status :close, branch, :green

        renderer.close_worktree(branch)
      end

      desc 'reset SKILL', 'Reset running/failed backlog items for a skill'
      def reset(skill)
        backlog_items = store.all_backlog(skill: skill).select do |bi|
          [BacklogStatus::Running, BacklogStatus::Failed].include?(bi.status) || (bi.status == BacklogStatus::Pending && bi.branch)
        end
        if backlog_items.empty?
          say_status :reset, "nothing to reset for #{skill}", :yellow
          return
        end

        backlog_items.each do |backlog_item|
          if backlog_item.branch
            renderer.close_worktree(backlog_item.branch)
            Integrations::Worktree.cleanup(backlog_item.branch)
          end
          store.update_backlog_status(backlog_item, BacklogStatus::Pending, branch: nil, failure_reason: nil)
          say "  ⬜ ##{backlog_item.id} #{backlog_item.item} → pending"
        end
        say_status :reset, "#{backlog_items.size} item(s) for #{skill}", :green
      end

      private

      def store = CLI.store
      def renderer = CLI.renderer
    end
  end
end
