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

      desc "status [SKILL]", "Show autolearn status dashboard"
      def status(skill = nil)
        Monitoring::AutolearnMonitor.new(store: store).status(skill: skill)
      end

      desc "report", "Show autolearn report (last 24h)"
      def report
        Monitoring::AutolearnMonitor.new(store: store).report
      end

      desc "inspect ID", "Inspect a backlog item and its autolearn cycles"
      def inspect(id)
        item = store.get_backlog_item(id)
        abort "nightshift: backlog item ##{id} not found" unless item

        puts ""
        puts "  ##{item.id} [#{item.skill}] #{item.item}"
        puts "  Status: #{item.status}#{item.failure_reason ? " (#{item.failure_reason})" : ""}"
        puts "  Retries: #{item.retry_count}/#{CI::Judge::MAX_RETRIES}  Last verdict: #{item.last_verdict || '-'}"
        puts "  Branch: #{item.branch || '-'}"
        puts "  PR: #{item.pr_number ? "##{item.pr_number}" : '-'}"

        cycles = store.cycles_for_item(item.id)
        if cycles.empty?
          puts "\n  No autolearn cycles."
        else
          puts "\n  Cycles (#{cycles.size}):"
          cycles.each do |c|
            conf = c.confidence ? format("%.1f", c.confidence) : "?"
            patch_status = if c.skill_patch_sha
                             "applied (#{c.skill_patch_sha[0, 7]})"
                           elsif c.suggested_patch
                             "suggested but NOT applied"
                           else
                             "none"
                           end
            puts "    ##{c.id}  attempt=#{c.attempt}  #{c.verdict}  confidence=#{conf}  patch=#{patch_status}"
            puts "         cause: #{c.root_cause[0, 100]}" if c.root_cause
            puts "         outcome: #{c.outcome}" if c.outcome
          end
        end
        puts ""
      end

      private

      def store = CLI.store
    end
  end
end
