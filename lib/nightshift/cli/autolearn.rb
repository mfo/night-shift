# frozen_string_literal: true
# typed: false

#
# CLI::Autolearn — Monitoring et inspection de la boucle autolearn
#
# La boucle autolearn fait tourner les skills automatiquement :
# le reconciler lance un skill, si échec le juge LLM analyse et décide
# de retrier (avec patch patterns.md) ou de skipper.
#
# Ces commandes donnent de la visibilité sur le processus :
#   status  — Dashboard par skill : items pending/running/done/failed + derniers cycles
#   report  — Rapport sur les dernières 24h : verdicts, patches, suggestions infra
#   inspect — Deep-dive sur un item : tous ses cycles, verdicts, patches appliqués
#
# Usage :
#   nightshift autolearn status [SKILL]
#   nightshift autolearn report
#   nightshift autolearn inspect 42

module Nightshift
  class CLI
    class Autolearn < Thor
      def self.exit_on_failure? = true

      desc 'status [SKILL]', 'Show autolearn status dashboard'
      def status(skill = nil)
        Monitoring::AutolearnMonitor.new(store: store).status(skill: skill)
      end

      desc 'report', 'Show autolearn report (last 24h)'
      def report
        Monitoring::AutolearnMonitor.new(store: store).report
      end

      desc 'inspect ID', 'Inspect a backlog item and its autolearn cycles'
      def inspect(id)
        backlog_item = store.get_backlog_item(id)
        abort "nightshift: backlog item ##{id} not found" unless backlog_item

        say ''
        say "  ##{backlog_item.id} [#{backlog_item.skill}] #{backlog_item.item}"
        say "  Status: #{backlog_item.status.serialize}#{backlog_item.failure_reason ? " (#{backlog_item.failure_reason})" : ''}"
        say "  Retries: #{backlog_item.retry_count}/#{CI::Judge::MAX_RETRIES}  Last verdict: #{backlog_item.last_verdict || '-'}"
        say "  Branch: #{backlog_item.branch || '-'}"
        say "  PR: #{backlog_item.pr_number ? "##{backlog_item.pr_number}" : '-'}"

        cycles = store.cycles_for_item(backlog_item)
        if cycles.empty?
          say "\n  No autolearn cycles."
        else
          say "\n  Cycles (#{cycles.size}):"
          cycles.each do |c|
            conf = c.confidence ? format('%.1f', c.confidence) : '?'
            patch_status = if c.skill_patch_sha
                             "applied (#{c.skill_patch_sha[0, 7]})"
                           elsif c.suggested_patch
                             'suggested but NOT applied'
                           else
                             'none'
                           end
            say "    ##{c.id}  attempt=#{c.attempt}  #{c.verdict}  confidence=#{conf}  patch=#{patch_status}"
            say "         cause: #{c.root_cause[0, 100]}" if c.root_cause
            say "         outcome: #{c.outcome}" if c.outcome
          end
        end
        say ''
      end

      private

      def store = CLI.store
    end
  end
end
