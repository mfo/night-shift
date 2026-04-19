module Nightshift
  module Brief
    module_function

    def generate(store)
      rows = store.all_prs
      prs = rows.map { |r| PR.from_db(r) }

      # Load previous states for transition detection
      last_brief = store.get_setting("last_brief")

      # Recent transitions from DB
      since = last_brief ? last_brief.to_i : 0
      transitions = store.db[:transitions]
        .where { created_at > since }
        .order(:created_at)
        .all

      puts "── morning brief ────────────────────────── #{Time.now.strftime('%d %b, %H:%M')}"
      puts ""

      # Categorize PRs
      open_prs = prs.select { |pr| pr.github_state == "OPEN" }
      deployed_prs = prs.select { |pr| pr.state == :deployed }

      # Actions requises
      actionable = open_prs.select { |pr| %i[ci_red changes_requested approved has_comments].include?(pr.state) }
      if actionable.any?
        puts "  ACTION REQUISE"
        puts ""
        actionable.each do |pr|
          puts "    #{pr.emoji}  ##{pr.number}  #{pr.slug}"
          label, cmd = action_for(pr)
          puts "       #{label}"
          puts "       #{cmd}"
        end
        puts ""
      end

      # Worktrees to cleanup — only show merged/deployed PRs that still have a worktree
      worktree_branches = Worktree.branches
      cleanup_prs = prs.select { |pr| %i[deployed merged].include?(pr.state) && worktree_branches.include?(pr.branch) }
      if cleanup_prs.any?
        puts "  WORKTREES À FERMER"
        puts ""
        cleanup_prs.each do |pr|
          puts "    #{pr.emoji}  ##{pr.number}  #{pr.slug}"
          puts "       → nightshift close #{pr.branch}"
        end
        puts ""
      end

      # Transitions
      if transitions.any?
        puts "  TRANSITIONS"
        puts ""
        transitions.each do |t|
          from_emoji = PR::EMOJI[t[:from_state].to_sym] || t[:from_state]
          to_emoji = PR::EMOJI[t[:to_state].to_sym] || t[:to_state]
          puts "    #{from_emoji}→#{to_emoji}  ##{t[:pr_number]}"
        end
        puts ""
      end

      # Summary bar
      counts = open_prs.group_by(&:state).transform_values(&:count)
      parts = []
      parts << "#{counts[:approved]}✅" if counts[:approved]
      parts << "#{counts[:ci_green]}🟢" if counts[:ci_green]
      parts << "#{counts[:ci_red]}🔴" if counts[:ci_red]
      parts << "#{counts[:changes_requested]}⛔" if counts[:changes_requested]
      parts << "#{counts[:has_comments]}💬" if counts[:has_comments]
      parts << "#{counts[:ci_running]}⏳" if counts[:ci_running]
      parts << "#{deployed_prs.size}🚀" if deployed_prs.any?

      puts "  #{open_prs.size} PRs ouvertes  #{parts.join(' ')}"
      puts ""
      puts "──────────────────────────────────────────────────────────"

      # Update timestamp
      store.set_setting("last_brief", Time.now.to_i.to_s)
    end

    def action_for(pr)
      case pr.state
      when :ci_red
        ["CI rouge", "→ autofix lancé"]
      when :approved
        ["approved", "→ nightshift merge #{pr.number}"]
      when :changes_requested
        ["changes requested", "→ adresser les retours"]
      when :has_comments
        ["#{pr.review_count} comment(s)", "→ lire les comments"]
      else
        ["", ""]
      end
    end
  end
end
