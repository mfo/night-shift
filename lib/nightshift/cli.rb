require "open3"
require "thor"

module Nightshift
  class CLI < Thor
    BINSTUB = File.expand_path("../../bin/nightshift-rb", __dir__).freeze

    map "skill-run" => :skill_run,
        "autolearn-status" => :autolearn_status,
        "autolearn-report" => :autolearn_report,
        "inspect" => :inspect_item

    def self.exit_on_failure? = true

    class << self
      attr_writer :store

      def store
        @store ||= Core::Store.new
      end
    end

    # --- PR lifecycle ---

    desc "merge PR_NUMBER", "Merge a PR with auto-squash"
    def merge(pr_number)
      system("gh", "pr", "merge", pr_number, "--auto", "--squash",
             chdir: ENV.fetch("NIGHTSHIFT_REPO"))
    end

    desc "brief", "Generate brief of open PRs"
    def brief
      Monitoring::Brief.generate(store)
    end

    desc "diagnose PR_NUMBER", "Diagnose CI failure for a PR"
    def diagnose(pr_number)
      Monitoring::Diagnose.run(pr_number)
    end

    desc "autofix PR_NUMBER", "Auto-fix CI failure for a PR"
    def autofix(pr_number)
      CI::Autofix.run(pr_number, store: store)
    end

    # --- Daemon ---

    desc "watch", "Watch and refresh PRs periodically"
    def watch
      interval = ENV.fetch("NIGHTSHIFT_WATCH_INTERVAL").to_i
      loop do
        refresh
        sleep interval
        Nightshift.reload!
      end
    end

    desc "attach", "Attach to tmux session"
    def attach
      UI::Attach.run
    end

    desc "auto", "Refresh then watch"
    def auto
      refresh
      watch
    end

    # --- Worktree ---

    desc "open BRANCH", "Open a new worktree and tmux window"
    def open(branch)
      repo_path = ENV.fetch("NIGHTSHIFT_REPO")
      session = ENV.fetch("NIGHTSHIFT_SESSION")
      wt_path = File.join(File.dirname(repo_path), branch)

      unless system("git", "-C", repo_path, "worktree", "add", wt_path, "main", "-b", branch)
        abort "nightshift: failed to create worktree #{branch}"
      end

      system("tmux", "new-window", "-t", session, "-n", "\u{1f528} #{branch}", "-c", wt_path)
      puts "nightshift: opened #{branch}"
    end

    desc "close BRANCH", "Close a worktree and tmux window"
    def close(branch)
      session = ENV.fetch("NIGHTSHIFT_SESSION")

      item = store.backlog_by_branch(branch)
      if item && %w[running pr_open].include?(item[:status])
        store.update_backlog_status(item[:id], "failed", failure_reason: "manual_close")
        puts "nightshift: backlog item marked failed (manual_close)"
      end

      Integrations::Worktree.cleanup(branch)
      puts "nightshift: closed #{branch}"

      renderer = UI::TmuxRenderer.new(session: session)
      renderer.close_worktree(branch)
    end

    desc "reset SKILL", "Reset running/failed backlog items for a skill"
    def reset(skill)
      session = ENV.fetch("NIGHTSHIFT_SESSION")
      renderer = UI::TmuxRenderer.new(session: session)

      items = store.all_backlog(skill: skill).select { |i|
        %w[running failed].include?(i[:status]) || (i[:status] == "pending" && i[:branch])
      }
      if items.empty?
        puts "nightshift: nothing to reset for #{skill}"
        return
      end

      items.each do |item|
        if item[:branch]
          renderer.close_worktree(item[:branch])
          Integrations::Worktree.cleanup(item[:branch])
        end
        store.update_backlog_status(item[:id], "pending", branch: nil, failure_reason: nil)
        puts "  \u2b1c ##{item[:id]} #{item[:item]} \u2192 pending"
      end
      puts "nightshift: reset #{items.size} item(s) for #{skill}"
    end

    # --- Skill pipeline ---

    desc "skill-run SKILL ITEM", "Run a skill pipeline on an item"
    def skill_run(skill, item_path)
      branch, = Open3.capture2("git", "rev-parse", "--abbrev-ref", "HEAD", chdir: Dir.pwd)
      backlog_item = store.backlog_by_branch(branch.strip)
      context = backlog_item&.dig(:context)

      Skills::Pipeline.new(store: store).execute(skill, item_path, worktree_path: Dir.pwd, context: context)
    end

    # --- Inspect ---

    desc "inspect ID", "Inspect a backlog item and its autolearn cycles"
    def inspect_item(id)
      item = store.get_backlog_item(id)
      abort "nightshift: backlog item ##{id} not found" unless item

      puts ""
      puts "  ##{item[:id]} [#{item[:skill]}] #{item[:item]}"
      puts "  Status: #{item[:status]}#{item[:failure_reason] ? " (#{item[:failure_reason]})" : ""}"
      puts "  Retries: #{item[:retry_count]}/#{CI::Judge::MAX_RETRIES}  Last verdict: #{item[:last_verdict] || '-'}"
      puts "  Branch: #{item[:branch] || '-'}"
      puts "  PR: #{item[:pr_number] ? "##{item[:pr_number]}" : '-'}"

      cycles = store.cycles_for_item(item[:id])
      if cycles.empty?
        puts "\n  No autolearn cycles."
      else
        puts "\n  Cycles (#{cycles.size}):"
        cycles.each do |c|
          conf = c[:confidence] ? format("%.1f", c[:confidence]) : "?"
          patch_status = if c[:skill_patch_sha]
                           "applied (#{c[:skill_patch_sha][0, 7]})"
                         elsif c[:suggested_patch]
                           "suggested but NOT applied"
                         else
                           "none"
                         end
          puts "    ##{c[:id]}  attempt=#{c[:attempt]}  #{c[:verdict]}  confidence=#{conf}  patch=#{patch_status}"
          puts "         cause: #{c[:root_cause][0, 100]}" if c[:root_cause]
          puts "         outcome: #{c[:outcome]}" if c[:outcome]
        end
      end
      puts ""
    end

    # --- Autolearn ---

    desc "autolearn-status [SKILL]", "Show autolearn status"
    def autolearn_status(skill = nil)
      Monitoring::AutolearnMonitor.new(store: store).status(skill: skill)
    end

    desc "autolearn-report", "Show autolearn report"
    def autolearn_report
      Monitoring::AutolearnMonitor.new(store: store).report
    end

    # --- Backlog subcommand ---

    desc "backlog SUBCOMMAND ...ARGS", "Manage backlog items"
    subcommand "backlog", Backlog

    no_commands do
      def store
        self.class.store
      end

      def refresh
        prs = Integrations::GitHub.fetch_prs
        renderer = UI::TmuxRenderer.new
        reconciler = Reconciler.new(store: store, renderer: renderer)
        reconciler.reconcile(prs)
        puts "#{Time.now.strftime('%H:%M:%S')} Refreshed (#{prs.size} PRs fetched, worktree-centric)"
      rescue Integrations::GitHub::Error => e
        $stderr.puts e.message
      end
    end
  end
end
