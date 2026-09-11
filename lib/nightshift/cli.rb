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

    # --- Internal (called inside panes by attach/reconciler) ---

    desc 'status', "Vue globale de l'encours : PRs, worktrees, et ce qui n'est pas suivi"
    option :deep, type: :boolean, default: false, desc: 'Mesure aussi le disque et l\'état git (plus lent)'
    def status
      primary = Nightshift.repo_path
      Nightshift.repos.each_with_index do |repo, index|
        report = Core::Inventory.scan(
          repo_path: repo,
          store: repo == primary ? store : nil,
          deep: options[:deep],
          probe_databases: repo == primary
        )
        puts '' if index.positive?
        Monitoring::Status.render(report)
      end
    end

    desc 'doctor', 'Dette de nettoyage : worktrees, dossiers fantômes, bases, branches'
    option :fix, type: :boolean, default: false, desc: 'Applique le nettoyage (dry-run sinon)'
    option :only, type: :string, desc: "Une seule catégorie : #{Monitoring::Doctor::CATEGORIES.map(&:key).join(', ')}"
    option :yes, type: :boolean, default: false, aliases: '-y', desc: 'Ne pas demander confirmation'
    def doctor
      only = options[:only]
      if only && Monitoring::Doctor.categories(only).empty?
        abort "nightshift: catégorie inconnue '#{only}' (#{Monitoring::Doctor::CATEGORIES.map(&:key).join(', ')})"
      end

      report = Core::Inventory.scan(store: store, deep: true)
      Monitoring::Doctor.render(report, only: only)
      return unless options[:fix]

      confirm = options[:yes] ? nil : ->(_category, items) { yes?("    supprimer ces #{items.size} élément(s) ? [y/N]") }
      tally = Monitoring::Doctor.apply(report, only: only, confirm: confirm)
      say_status :doctor, "#{tally.values.sum} élément(s) nettoyé(s)", :green
    end

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
