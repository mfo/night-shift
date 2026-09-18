# frozen_string_literal: true
# typed: true

require 'fileutils'

module Nightshift
  module Monitoring
    #
    # Doctor — the cleanup debt, measured, then reclaimed on demand.
    #
    # Nothing here deletes anything unless `apply` is called explicitly, and
    # `apply` only ever touches items that passed `safe_to_clean?`. A worktree
    # holding uncommitted or unpushed work is reported and skipped: those
    # changes exist as no git object anywhere, so they are not recoverable once
    # the worktree is gone.
    #
    module Doctor
      extend T::Sig
      module_function

      Category = Struct.new(:key, :action, :title, :hint, keyword_init: true)

      CATEGORIES = [
        Category.new(key: 'worktrees', action: CleanupAction::CloseWorktree,
                     title: 'WORKTREES DONT LA PR EST CLOSE',
                     hint: 'worktree supprimé, bases de test droppées, branche locale supprimée'),
        Category.new(key: 'admin', action: CleanupAction::PruneAdmin,
                     title: 'ENTRÉES ADMIN SANS DOSSIER',
                     hint: 'git worktree prune'),
        Category.new(key: 'ghosts', action: CleanupAction::RemoveDir,
                     title: 'DOSSIERS FANTÔMES',
                     hint: 'dossiers qu aucun worktree ne revendique'),
        Category.new(key: 'dbs', action: CleanupAction::DropDatabase,
                     title: 'BASES DE TEST ORPHELINES',
                     hint: 'dropdb'),
        Category.new(key: 'branches', action: CleanupAction::DeleteBranch,
                     title: 'BRANCHES MERGÉES SANS WORKTREE',
                     hint: 'git branch -d, qui refuse tout ce qui n est pas mergé')
      ].freeze

      MAX_LISTED = 12

      sig { params(key: T.nilable(String)).returns(T::Array[Category]) }
      def categories(key = nil)
        return CATEGORIES unless key

        CATEGORIES.select { |c| c.key == key }
      end

      sig { params(report: Core::Inventory::Report, only: T.nilable(String), io: IO).void }
      def render(report, only: nil, io: $stdout)
        io.puts "── doctor ────────────────────────────── #{File.basename(report.repo)}"
        io.puts ''

        selected = categories(only)
        selected.each { |category| render_category(report, category, io) }
        render_blocked(report, selected, io)
        render_footer(report, only, io)
      end

      sig { params(report: Core::Inventory::Report, category: Category, io: IO).void }
      def render_category(report, category, io)
        items = report.for_action(category.action).select(&:safe_to_clean?)
        return if items.empty?

        bytes = items.sum(&:size_bytes)
        suffix = bytes.positive? ? "   #{Nightshift.human_size(bytes)}" : ''
        io.puts "  #{category.title} (#{items.size})#{suffix}"
        io.puts ''
        items.sort_by { |i| -i.size_bytes }.first(MAX_LISTED).each do |item|
          io.puts "    #{describe(item)}"
        end
        io.puts "    … et #{items.size - MAX_LISTED} autre(s)" if items.size > MAX_LISTED
        io.puts ''
      end

      sig { params(item: Core::WorkItem).returns(String) }
      def describe(item)
        pr = item.pr_number ? "##{item.pr_number}" : ''
        size = item.human_size
        parts = [item.label.slice(0, 52).to_s.ljust(52), pr.ljust(7), size.rjust(8)]
        parts << " #{item.reason}" if item.reason
        parts.join(' ').rstrip
      end

      # Items the doctor found but refuses to touch. Listed loudly: they are the
      # ones holding work, and the only ones a human has to decide about.
      sig { params(report: Core::Inventory::Report, selected: T::Array[Category], io: IO).void }
      def render_blocked(report, selected, io)
        actions = selected.map(&:action)
        blocked = report.blocked.select { |i| actions.include?(i.cleanup) }
        return if blocked.empty?

        io.puts "  ⛔ NON TOUCHÉS (#{blocked.size})   #{Nightshift.human_size(blocked.sum(&:size_bytes))}"
        io.puts ''
        blocked.sort_by { |i| -i.size_bytes }.first(MAX_LISTED).each do |item|
          io.puts "    #{item.label.slice(0, 52).ljust(52)} #{item.blockers.join(', ')}"
          io.puts "      #{item.path}" if item.path
        end
        io.puts "    … et #{blocked.size - MAX_LISTED} autre(s)" if blocked.size > MAX_LISTED
        io.puts ''
      end

      sig { params(report: Core::Inventory::Report, only: T.nilable(String), io: IO).void }
      def render_footer(report, only, io)
        actions = categories(only).map(&:action)
        items = report.cleanables.select { |i| actions.include?(i.cleanup) && i.safe_to_clean? }

        if items.empty?
          io.puts '  ✓ rien à nettoyer'
          return
        end

        io.puts "  #{items.size} élément(s) · #{Nightshift.human_size(items.sum(&:size_bytes))} récupérables"
        io.puts ''
        io.puts "  → nightshift doctor --fix#{only ? " --only #{only}" : ''}"
      end

      #
      # Reclaim. Returns a per-category tally of what was actually done.
      #
      sig do
        params(report: Core::Inventory::Report, only: T.nilable(String),
               io: IO, confirm: T.nilable(T.proc.params(category: Category, items: T::Array[Core::WorkItem]).returns(T::Boolean)))
          .returns(T::Hash[String, Integer])
      end
      def apply(report, only: nil, io: $stdout, confirm: nil)
        tally = Hash.new(0)

        categories(only).each do |category|
          items = report.for_action(category.action).select(&:safe_to_clean?)
          next if items.empty?

          io.puts ''
          io.puts "  #{category.title} — #{items.size} élément(s), #{Nightshift.human_size(items.sum(&:size_bytes))}"
          next if confirm && !confirm.call(category, items)

          tally[category.key] = run(category.action, items, report.repo, io)
        end

        tally
      end

      sig { params(action: CleanupAction, items: T::Array[Core::WorkItem], repo: String, io: IO).returns(Integer) }
      def run(action, items, repo, io)
        case action
        when CleanupAction::PruneAdmin
          Integrations::Git.prune_worktrees(repo)
          io.puts "    ✓ #{items.size} entrée(s) admin prunée(s)"
          items.size
        when CleanupAction::DropDatabase
          Integrations::Worktree.drop_databases(items.map(&:label))
          io.puts "    ✓ #{items.size} base(s) droppée(s)"
          items.size
        when CleanupAction::CloseWorktree
          close_worktrees(items, repo, io)
        when CleanupAction::RemoveDir
          items.count { |item| remove_dir(item, io) }
        when CleanupAction::DeleteBranch
          delete_branches(items, repo, io)
        else 0
        end
      end

      sig { params(items: T::Array[Core::WorkItem], repo: String, io: IO).returns(Integer) }
      def close_worktrees(items, repo, io)
        items.count do |item|
          branch = item.branch
          unless branch
            io.puts "    ⊘ #{item.label} — worktree détaché, à fermer à la main"
            next false
          end

          Integrations::Worktree.cleanup(branch, repo_path: repo)
          io.puts "    ✓ #{branch}"
          true
        end
      end

      sig { params(item: Core::WorkItem, io: IO).returns(T::Boolean) }
      def remove_dir(item, io)
        path = item.path
        return false unless path && Dir.exist?(path)

        FileUtils.rm_rf(path)
        io.puts "    ✓ #{path}"
        true
      end

      sig { params(items: T::Array[Core::WorkItem], repo: String, io: IO).returns(Integer) }
      def delete_branches(items, repo, io)
        deleted = items.count do |item|
          item.branch && Integrations::Git.delete_branch(repo, T.must(item.branch))
        end
        refused = items.size - deleted
        io.puts "    ✓ #{deleted} branche(s) supprimée(s)"
        io.puts "    ⊘ #{refused} refusée(s) par git (non mergées)" if refused.positive?
        deleted
      end
    end
  end
end
