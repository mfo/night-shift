# frozen_string_literal: true
# typed: false

#
# CLI — Point d'entrée Thor pour nightshift-rb
#
# Squelette principal : store partagé, commande attach (point d'entrée),
# watch (boucle interne), skill-run (interne), et subcommands.
#
# Les commandes métier sont dans des fichiers dédiés :
#   cli/backlog.rb    — CRUD backlog items (add, scan, list, skip, retry)
#   cli/pr.rb         — Cycle de vie PR (merge, brief, diagnose, autofix)
#   cli/worktree.rb   — Gestion worktrees + fenêtres (open, close, reset)
#   cli/autolearn.rb  — Monitoring autolearn (status, report, inspect)

require 'open3'
require 'thor'

module Nightshift
  class CLI < Thor
    def self.exit_on_failure? = true

    class_option :renderer, type: :string, enum: %w[tmux iterm2],
                            default: ENV.fetch('NIGHTSHIFT_RENDERER', 'tmux'),
                            desc: 'Terminal multiplexer adapter (tmux or iterm2)'

    class << self
      attr_writer :store, :renderer

      def store
        @store ||= Core::Store.new
      end

      def renderer
        @renderer ||= UI::TmuxAdapter.new
      end
    end

    # --- Entry point ---

    desc 'attach', 'Create/attach session and start watching PRs'
    def attach
      UI::Attach.run(renderer: build_renderer)
    end

    desc 'backend', 'Show which backend the schedule selects right now'
    method_option :at, type: :string, desc: 'Simulate a time of day (HH:MM) instead of now'
    def backend
      now = Time.now
      if options[:at]
        minutes = Core::BackendWindow.parse_time(options[:at])
        now = Time.new(now.year, now.month, now.day) + (minutes * 60)
      end
      window = Nightshift.active_window(now: now)
      active = Nightshift.active_backend(now: now)

      puts "now      : #{now.strftime('%H:%M')}"
      puts "backend  : #{active.name} (#{active.harness}, concurrency #{active.concurrency})"
      puts "window   : #{window ? "#{window.label} → #{window.backend}" : 'aucune plage active (default_backend)'}"
      switch = Nightshift.next_switch_at(now: now)
      puts "next     : #{switch ? switch.strftime('%a %H:%M') : 'jamais (pas de schedule)'}"
      puts

      Nightshift.skill_names.sort.each do |skill|
        b = Nightshift.backend_for(skill, now: now)
        pinned = (Nightshift.skills.dig(skill, :backend) ? ' (pinned)' : '')
        puts format('  %-20s %s%s', skill, b.harness, pinned)
      end
    end

    # --- Internal (called inside panes by attach/reconciler) ---

    desc 'watch', 'Refresh and watch PRs periodically (internal, runs in pane)', hide: true
    def watch
      interval = ENV.fetch('NIGHTSHIFT_WATCH_INTERVAL').to_i
      loop do
        refresh
        sleep interval
        Nightshift.reload!
      end
    end

    desc 'skill_run SKILL ITEM', 'Run a skill pipeline on an item (internal)', hide: true
    def skill_run(skill, item_path)
      branch, = Open3.capture2('git', 'rev-parse', '--abbrev-ref', 'HEAD', chdir: Dir.pwd)
      backlog_item = store.backlog_by_branch(branch.strip)
      abort "nightshift: no backlog item for branch #{branch.strip}" unless backlog_item

      Skills::Pipeline.new(store: store).execute(backlog_item)
    end

    desc 'skill_run_batch SKILL BATCH_ID', 'Run a batch of skill items (internal)', hide: true
    def skill_run_batch(skill, batch_id)
      backlog_items = store.backlog_items_for_batch(batch_id)
      abort "nightshift: no items found for batch #{batch_id}" if backlog_items.empty?

      Skills::Pipeline.new(store: store).execute_batch(backlog_items)
    end

    # --- Subcommands ---

    desc 'backlog SUBCOMMAND ...ARGS', 'Manage backlog items'
    subcommand 'backlog', Backlog

    desc 'pr SUBCOMMAND ...ARGS', 'PR lifecycle (merge, brief, diagnose, autofix)'
    subcommand 'pr', PR

    desc 'worktree SUBCOMMAND ...ARGS', 'Manage git worktrees and windows'
    subcommand 'worktree', Worktree

    desc 'autolearn SUBCOMMAND ...ARGS', 'Autolearn monitoring and inspection'
    subcommand 'autolearn', Autolearn

    no_commands do
      def store
        self.class.store
      end

      def refresh
        prs = Integrations::GitHub.fetch_prs
        renderer = self.class.renderer
        reconciler = Reconciler.new(store: store, renderer: renderer)
        reconciler.reconcile(prs)
        Log.info "Refreshed (#{prs.size} PRs fetched, worktree-centric)"
      rescue Integrations::GitHub::Error => e
        Log.error e.message
      end

      def build_renderer
        choice = options[:renderer] || ENV.fetch('NIGHTSHIFT_RENDERER', 'tmux')
        r = case choice
            when 'iterm2' then UI::TmuxAdapter.new(mode: :cc)
            else UI::TmuxAdapter.new
            end
        self.class.renderer = r
        r
      end

    end
  end
end
