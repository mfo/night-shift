# frozen_string_literal: true
# typed: false

#
# CLI::PR — Cycle de vie des Pull Requests
#
# Commandes pour interagir avec les PRs du repo cible :
#   merge    — Auto-merge squash via gh
#   brief    — Morning brief : actions requises sur les PRs ouvertes
#   diagnose — Catégorise les échecs CI (linter/unit/system/codeql)
#   autofix  — Débloquer la CI : fix linters, fix specs, retry flaky
#
# Usage :
#   nightshift pr merge 12345
#   nightshift pr brief
#   nightshift pr diagnose 12345
#   nightshift pr autofix 12345

module Nightshift
  class CLI
    class PR < Thor
      def self.exit_on_failure? = true

      desc 'merge PR_NUMBER', 'Merge a PR with auto-squash'
      def merge(pr_number)
        system('gh', 'pr', 'merge', pr_number, '--auto', '--squash',
               chdir: Nightshift.repo_path)
      end

      desc 'brief', 'Generate brief of open PRs'
      def brief
        Monitoring::Brief.generate(store)
      end

      desc 'diagnose PR_NUMBER', 'Diagnose CI failure for a PR'
      def diagnose(pr_number)
        Monitoring::Diagnose.run(pr_number)
      end

      desc 'autofix PR_NUMBER', 'Auto-fix CI failure for a PR'
      def autofix(pr_number)
        CI::Autofix.run(pr_number, store: store)
      end

      private

      def store = CLI.store
    end
  end
end
