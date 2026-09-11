# frozen_string_literal: true
# typed: true

module Nightshift
  module Monitoring
    #
    # Status — the whole encours on one screen.
    #
    # Brief answers "what needs me right now". This answers "what do I have
    # open, at all" — including the PRs the reconciler cannot see because they
    # have no local worktree, and the worktrees that have no PR at all.
    #
    module Status
      extend T::Sig
      module_function

      sig { params(report: Core::Inventory::Report, io: IO).void }
      def render(report, io: $stdout)
        io.puts "── encours ───────────────────────────── #{File.basename(report.repo)}"
        io.puts ''
        io.puts '  ⚠ GitHub injoignable — PRs lues depuis le cache local' if report.pr_fetch_failed
        io.puts '' if report.pr_fetch_failed

        render_open_prs(report, io)
        render_worktrees_without_pr(report, io)
        render_footer(report, io)
      end

      sig { params(report: Core::Inventory::Report, io: IO).void }
      def render_open_prs(report, io)
        open_prs = report.open_prs.sort_by { |i| [i.path ? 0 : 1, -i.pr_number.to_i] }
        return if open_prs.empty?

        io.puts "  PRs OUVERTES (#{open_prs.size})"
        io.puts ''
        open_prs.each do |item|
          io.puts "    #{line_for(item)}"
          next if item.path

          io.puts "         ↳ pas de worktree → nightshift worktree open #{item.branch}"
        end
        io.puts ''
      end

      sig { params(report: Core::Inventory::Report, io: IO).void }
      def render_worktrees_without_pr(report, io)
        orphans = report.worktrees_without_pr.reject(&:missing_dir)
        return if orphans.empty?

        io.puts "  WORKTREES SANS PR (#{orphans.size})"
        io.puts ''
        orphans.sort_by { |i| i.label.to_s }.each do |item|
          badge = item.origin == WorkItemOrigin::Auto ? '🤖' : '🔨'
          suffix = item.locked ? '  🔒' : ''
          io.puts "    #{badge}  #{item.label}#{suffix}"
        end
        io.puts ''
      end

      sig { params(item: Core::WorkItem).returns(String) }
      def line_for(item)
        emoji = item.pr_state ? (Core::PR::EMOJI[item.pr_state] || '◯') : '◯'
        origin = item.origin == WorkItemOrigin::Auto ? '🤖' : '  '
        anchor = item.path ? File.basename(T.must(item.path)) : '—'
        format('%<e>s  #%<n>d  %<b>-44s %<o>s %<a>s',
               e: emoji, n: item.pr_number.to_i, b: item.label.slice(0, 44), o: origin, a: anchor)
      end

      sig { params(report: Core::Inventory::Report, io: IO).void }
      def render_footer(report, io)
        parts = []
        missing = report.prs_without_worktree.size
        parts << "#{missing} PR(s) sans worktree" if missing.positive?
        closable = report.for_action(CleanupAction::CloseWorktree).size
        parts << "#{closable} worktree(s) à fermer" if closable.positive?

        io.puts "  #{report.worktrees.size} worktrees · #{report.open_prs.size} PRs ouvertes"
        io.puts "  #{parts.join(' · ')}" if parts.any?

        debt = report.cleanables.size
        return unless debt.positive?

        suffix = report.deep ? " (#{Nightshift.human_size(report.reclaimable_bytes)})" : ''
        io.puts "  🧹 #{debt} élément(s) à nettoyer#{suffix} → nightshift doctor"
      end
    end
  end
end
