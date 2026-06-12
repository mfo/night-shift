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
#   cli/worktree.rb   — Gestion worktrees + tmux (open, close, reset)
#   cli/autolearn.rb  — Monitoring autolearn (status, report, inspect)

require 'open3'
require 'thor'

module Nightshift
  class CLI < Thor
    def self.exit_on_failure? = true

    class << self
      attr_writer :store

      def store
        @store ||= Core::Store.new
      end
    end

    # --- Entry point ---

    desc 'attach', 'Create/attach tmux session and start watching PRs'
    def attach
      UI::Attach.run
    end

    # --- Internal (called inside tmux panes by attach/reconciler) ---

    desc 'watch', 'Refresh and watch PRs periodically (internal, runs in tmux pane)', hide: true
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

    desc 'worktree SUBCOMMAND ...ARGS', 'Manage git worktrees and tmux windows'
    subcommand 'worktree', Worktree

    desc 'autolearn SUBCOMMAND ...ARGS', 'Autolearn monitoring and inspection'
    subcommand 'autolearn', Autolearn

    no_commands do
      def store
        self.class.store
      end

      def refresh
        prs = Integrations::GitHub.fetch_prs
        renderer = UI::TmuxRenderer.new
        reconciler = Reconciler.new(store: store, renderer: renderer)
        reconciler.reconcile(prs)
        Log.info "Refreshed (#{prs.size} PRs fetched, worktree-centric)"
      rescue Integrations::GitHub::Error => e
        Log.error e.message
      end
    end
  end
end
