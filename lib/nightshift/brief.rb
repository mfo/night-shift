require "open3"

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

      # Actions requises
      actionable = open_prs.select { |pr| %i[ci_red changes_requested approved has_comments].include?(pr.state) }
      if actionable.any?
        puts "  ACTION REQUISE"
        puts ""
        actionable.each do |pr|
          puts "    #{pr.badge}  ##{pr.number}  #{pr.slug}"
          actions_for(pr).each { |line| puts "       #{line}" }
          if pr.review_count.to_i > 0 || pr.comment_count.to_i > 0
            all = fetch_all_comments(pr.number)
            all[:review].each do |c|
              puts ""
              puts "          💬 #{c[:author]} — #{c[:path]}:#{c[:line]}"
              puts "          #{c[:body]}"
              puts "          vim +#{c[:line]} #{c[:path]}   #{c[:url]}"
            end
            all[:issue].each do |c|
              puts ""
              puts "          💬 #{c[:author]}"
              puts "          #{c[:body]}"
              puts "          #{c[:url]}"
            end
          end
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

      # Transitions — collapse ping-pong per PR, show only net change
      if transitions.any?
        # Group by PR, keep first from_state and last to_state
        net = transitions.group_by { |t| t[:pr_number] }.filter_map do |pr_num, ts|
          first_from = ts.first[:from_state]
          last_to = ts.last[:to_state]
          next if first_from == last_to # ping-pong: no net change
          { pr_number: pr_num, from_state: first_from, to_state: last_to, count: ts.size }
        end

        if net.any?
          puts "  TRANSITIONS"
          puts ""
          net.each do |t|
            from_emoji = PR::EMOJI[t[:from_state].to_sym] || t[:from_state]
            to_emoji = PR::EMOJI[t[:to_state].to_sym] || t[:to_state]
            suffix = t[:count] > 1 ? " (#{t[:count]} changes)" : ""
            puts "    #{from_emoji}→#{to_emoji}  ##{t[:pr_number]}#{suffix}"
          end
          puts ""
        end
      end

      # Summary bar (open PRs only)
      counts = open_prs.group_by(&:state).transform_values(&:count)
      parts = []
      parts << "#{counts[:approved]}✅" if counts[:approved]
      parts << "#{counts[:ci_green]}🟢" if counts[:ci_green]
      parts << "#{counts[:ci_red]}🔴" if counts[:ci_red]
      parts << "#{counts[:changes_requested]}⛔" if counts[:changes_requested]
      parts << "#{counts[:has_comments]}💬" if counts[:has_comments]
      parts << "#{counts[:ci_running]}⏳" if counts[:ci_running]
      parts << "#{cleanup_prs.size}🧹" if cleanup_prs.any?

      puts "  #{open_prs.size} PRs ouvertes  #{parts.join(' ')}"

      # Backlog summary
      items = store.all_backlog
      if items.any?
        bl = items.group_by { |i| i[:status] }.transform_values(&:size)
        bl_parts = bl.map { |k, v| "#{v} #{k}" }.join(", ")
        puts "  backlog: #{bl_parts}"
      end

      puts ""
      puts "──────────────────────────────────────────────────────────"

      # Update timestamp
      store.set_setting("last_brief", Time.now.to_i.to_s)
    end

    def fetch_review_comments(pr_number)
      repo = GitHub.gh_repo
      jq = '.[] | "\(.user.login)\t\(.path)\t\(.line // .original_line // "")\t\(.html_url)\t\(.body)"'
      out, = Open3.capture2("gh", "api", "repos/#{repo}/pulls/#{pr_number}/comments",
                            "--jq", jq)
      out.lines.filter_map do |line|
        parts = line.strip.split("\t", 5)
        next if parts.size < 5 || parts[4].empty?
        { author: parts[0], path: parts[1], line: parts[2], url: parts[3], body: parts[4] }
      end
    rescue StandardError
      []
    end

    def fetch_issue_comments(pr_number)
      repo = GitHub.gh_repo
      jq = '.[] | "\(.user.login)\t\(.html_url)\t\(.body)"'
      out, = Open3.capture2("gh", "api", "repos/#{repo}/issues/#{pr_number}/comments",
                            "--jq", jq)
      out.lines.filter_map do |line|
        parts = line.strip.split("\t", 3)
        next if parts.size < 3 || parts[2].empty?
        { author: parts[0], url: parts[1], body: parts[2].lines.first&.strip || parts[2].strip }
      end
    rescue StandardError
      []
    end

    def fetch_all_comments(pr_number)
      review = fetch_review_comments(pr_number)
      issue = fetch_issue_comments(pr_number)
      { review: review, issue: issue }
    end

    def actions_for(pr)
      lines = []
      lines << "CI rouge → autofix lancé" if pr.ci == "red"
      lines << "approved → nightshift merge #{pr.number}" if pr.review_decision == "APPROVED"
      lines << "changes requested → adresser les retours" if pr.review_decision == "CHANGES_REQUESTED"
      total = pr.review_count.to_i + pr.comment_count.to_i
      lines << "💬 #{total} comment(s) → gh pr view #{pr.number} --comments" if total > 0
      lines
    end

    def pane_brief_for(pr)
      lines = []
      lines << "── PR ##{pr.number} #{pr.badge} #{pr.slug} ──"
      lines << "  state: #{pr.state}  ci: #{pr.ci || 'none'}  review: #{pr.review_decision || 'none'}"

      actions_for(pr).each { |a| lines << "  → #{a}" }

      if pr.review_count.to_i > 0 || pr.comment_count.to_i > 0
        all = fetch_all_comments(pr.number)
        all[:review].each do |c|
          lines << ""
          lines << "  💬 #{c[:author]} — #{c[:path]}:#{c[:line]}"
          lines << "  #{c[:body]}"
          lines << "  vim +#{c[:line]} #{c[:path]}   #{c[:url]}"
        end
        all[:issue].each do |c|
          lines << ""
          lines << "  💬 #{c[:author]}"
          lines << "  #{c[:body]}"
          lines << "  #{c[:url]}"
        end
      end

      lines << ""
      lines.join("\n")
    end

    def write_pane_brief(pr, worktree_path)
      dir = File.join(worktree_path, "tmp")
      FileUtils.mkdir_p(dir)
      path = File.join(dir, "pr-brief.txt")
      File.write(path, pane_brief_for(pr))
      path
    end
  end
end
