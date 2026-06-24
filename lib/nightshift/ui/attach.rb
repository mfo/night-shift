# frozen_string_literal: true

require 'open3'

module Nightshift
  module UI
    #
    # Attach — Session bootstrap
    #
    # Creates a multiplexer session with one window per worktree, sets up
    # pane titles with PR badges, queues autofix for red PRs, proposes
    # merge for approved PRs, and launches the watch loop in main.
    #
    module Attach
      extend T::Sig
      module_function

      sig { params(renderer: Renderer).void }
      def run(renderer: TmuxAdapter.new)
        repo_path = Nightshift.repo_path
        session = ENV.fetch('NIGHTSHIFT_SESSION')

        if renderer.session_exists?
          reattach(renderer, session)
          return
        end

        puts ''
        puts '  nightshift'
        puts ''

        worktrees = Integrations::Worktree.list(repo_path)
        puts "  ◎ #{worktrees.size} worktrees found"

        puts '  ◎ fetching PRs from GitHub ...'
        store = Core::Store.new
        begin
          prs = Integrations::GitHub.fetch_prs
          prs.each { |pr| store.reconcile_pr(pr) }
          open_count = prs.count { |pr| pr.github_state == 'OPEN' }
          puts "  ✓ #{open_count} open PRs"
        rescue Integrations::GitHub::Error => e
          warn "  ⚠ #{e.message}"
          prs = store.all_prs.map { |r| Core::PR.from_db(r) }
          puts "  ⚠ using cached PRs (#{prs.size})"
        end

        pr_by_branch = prs.each_with_object({}) { |pr, h| h[pr.branch] = pr }

        puts '  ◎ building session ...'
        main_path = Integrations::Worktree.main_path(repo_path)
        renderer.create_session(main_path: main_path)

        n_red = 0
        n_green = 0
        n_running = 0
        n_approved = 0
        approved_prs = []
        cleanup_prs = []

        worktrees.each do |wt_path, wt_branch|
          pr = pr_by_branch[wt_branch]
          name = if pr
                   pr.window_name
                 elsif wt_branch.start_with?('auto/')
                   "🤖 #{wt_branch.sub('auto/', '')}"
                 else
                   "🔨 #{wt_branch}"
                 end

          win_id = renderer.create_window(name: name, path: wt_path, branch: wt_branch)
          renderer.set_window_metadata(window_id: win_id, key: '@worktree_path', value: wt_path)

          if pr
            renderer.set_pane_title(window_id: win_id, title: renderer.pane_brief_line(pr))
          else
            renderer.set_pane_title(window_id: win_id, title: wt_branch)
          end

          if pr
            case pr.ci
            when 'red' then n_red += 1
            when 'green' then n_green += 1
            when 'running' then n_running += 1
            end

            Monitoring::Brief.write_pane_brief(pr, wt_path)
            renderer.send_keys(target: "#{win_id}.0", command: 'cat tmp/pr-brief.txt')

            if pr.ci == 'red' && pr.github_state == 'OPEN'
              renderer.send_keys(target: "#{win_id}.0",
                                 command: "#{Nightshift.binstub_cmd} pr autofix #{pr.number}")
            elsif pr.review_decision == 'APPROVED' && pr.github_state == 'OPEN' && !pr.auto_merge
              n_approved += 1
              approved_prs << { number: pr.number, branch: wt_branch, slug: pr.slug, win_id: win_id }
            end

            if %w[MERGED].include?(pr.github_state)
              cleanup_prs << { number: pr.number, branch: wt_branch, slug: pr.slug, deployed: pr.deployed,
                               win_id: win_id }
            end
          end

          puts "    #{name}"
        end

        status_parts = ''
        status_parts += " #{n_approved}✅" if n_approved.positive?
        status_parts += " #{n_green}🟢" if n_green.positive?
        status_parts += " #{n_red}🔴" if n_red.positive?
        status_parts += " #{n_running}⏳" if n_running.positive?

        puts ''
        puts "  ✓ session ready#{status_parts}"
        puts "  ◎ autofix queued for #{n_red} red PR(s)" if n_red.positive?
        puts "  ◎ merge proposed for #{n_approved} approved PR(s)" if n_approved.positive?
        puts "  ◎ #{cleanup_prs.size} worktree(s) to cleanup" if cleanup_prs.any?
        puts '  ◎ launching morning brief ...'
        puts ''

        renderer.send_keys(target: "#{session}:0",
                           command: "#{Nightshift.binstub_cmd} pr brief && #{Nightshift.binstub_cmd} watch")
        renderer.select_main_window

        if approved_prs.any? || cleanup_prs.any?
          renderer.on_post_attach(approved_prs: approved_prs, cleanup_prs: cleanup_prs, session: session)
        end

        renderer.attach_or_switch
      end

      def reattach(renderer, _session)
        store = Core::Store.new
        last_brief = store.get_setting('last_brief')
        if last_brief.nil? || (Time.now.to_i - last_brief.to_i) > 14_400
          puts "nightshift: brief outdated, run '#{Nightshift.binstub_cmd} pr brief'"
        end

        puts "nightshift: session exists, attaching (use 'refresh' to update)"
        renderer.attach_or_switch
      end

    end
  end
end
