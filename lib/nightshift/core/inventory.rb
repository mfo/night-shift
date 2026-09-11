# frozen_string_literal: true
# typed: true

require 'set'

module Nightshift
  module Core
    #
    # Inventory — one honest picture of everything in flight, and everything
    # left behind.
    #
    # Nightshift used to see only what it had produced itself: the reconciler
    # kept the PRs whose branch had a local worktree, and the tmux session was
    # built by looping over worktrees. Anything else — a PR opened by hand with
    # no worktree, a worktree whose PR was merged three weeks ago, a directory
    # git no longer knows about, a test database nobody claims — was invisible.
    #
    # This crosses the four sources nobody was crossing:
    #   - git worktrees (porcelain: detached, locked and missing ones included)
    #   - GitHub PRs (all of them, not just the ones with a worktree)
    #   - postgres test databases
    #   - the nightshift backlog (to tell auto from manual)
    #
    # `scan` is strictly read-only. `deep: true` additionally asks git whether
    # each candidate holds uncommitted or unpushed work, and measures disk —
    # slower, and only the doctor needs it.
    #
    module Inventory
      extend T::Sig
      module_function

      CONCURRENCY = 8

      class Report < T::Struct
        extend T::Sig

        const :repo, String
        const :items, T::Array[WorkItem]
        const :deep, T::Boolean, default: false
        const :stale_branch_count, Integer, default: 0
        const :pr_fetch_failed, T::Boolean, default: false

        sig { params(kind: WorkItemKind).returns(T::Array[WorkItem]) }
        def of(kind) = items.select { |i| i.kind == kind }

        sig { returns(T::Array[WorkItem]) }
        def worktrees = of(WorkItemKind::Worktree)

        # Everything open on GitHub, whether or not it has a worktree here.
        # A branch can be both merged into base and still carry an open PR, so
        # stale branches are excluded to keep the count honest.
        sig { returns(T::Array[WorkItem]) }
        def open_prs
          items.select { |i| i.open_pr? && i.kind != WorkItemKind::StaleBranch }
        end

        sig { returns(T::Array[WorkItem]) }
        def prs_without_worktree = of(WorkItemKind::Pr)

        sig { returns(T::Array[WorkItem]) }
        def worktrees_without_pr = worktrees.select { |i| i.pr_number.nil? }

        sig { returns(T::Array[WorkItem]) }
        def cleanables = items.select { |i| i.cleanup }

        sig { returns(T::Array[WorkItem]) }
        def blocked = cleanables.reject(&:safe_to_clean?)

        sig { params(action: CleanupAction).returns(T::Array[WorkItem]) }
        def for_action(action) = cleanables.select { |i| i.cleanup == action }

        sig { returns(Integer) }
        def reclaimable_bytes = cleanables.select(&:safe_to_clean?).sum(&:size_bytes)
      end

      sig do
        params(repo_path: String, prs: T.nilable(T::Array[Core::PR]),
               store: T.nilable(Store), deep: T::Boolean,
               base: T.nilable(String), probe_databases: T::Boolean,
               history: T.nilable(T::Array[Core::PR])).returns(Report)
      end
      def scan(repo_path: Nightshift.repo_path, prs: nil, store: nil, deep: false,
               base: nil, probe_databases: true, history: nil)
        fetch_failed = false
        live = prs.nil?
        if prs.nil?
          prs = begin
            Integrations::GitHub.fetch_prs(repo_path)
          rescue StandardError => e
            # gh echoes the whole GraphQL query back on failure; one line is plenty.
            Log.warn "inventory: GitHub unreachable (#{e.message.lines.first.to_s.strip.slice(0, 120)}) " \
                     '— falling back on the local cache'
            fetch_failed = true
            (store&.all_prs || []).map { |row| Core::PR.from_db(row) }
          end
        end

        base ||= Integrations::Git.default_base(repo_path)
        entries = Integrations::Worktree.entries(repo_path)
        main = entries.first
        worktrees = main ? entries.drop(1) : entries

        history ||= fetch_history(repo_path) if live && !fetch_failed
        # History fills the gaps; the richly fetched PRs win wherever both know
        # about a branch, since only they carry CI and review state.
        by_branch = index_prs(history || []).merge(index_prs(prs))
        auto_branches = auto_branches_from(store)

        items = []
        items.concat(worktree_items(worktrees, repo_path, by_branch, auto_branches))
        items.concat(pr_items(prs, worktrees, repo_path, auto_branches))
        items.concat(ghost_items(repo_path))
        # The test databases are named after the primary repo's worktrees. Asking
        # a secondary repo which ones are orphaned would declare every database
        # of the primary repo unclaimed.
        items.concat(orphan_db_items(repo_path)) if probe_databases

        stale = stale_branch_items(repo_path, entries, by_branch, base)
        items.concat(stale)

        enrich!(items) if deep

        Report.new(repo: repo_path, items: items, deep: deep,
                   stale_branch_count: stale.size, pr_fetch_failed: fetch_failed)
      end

      sig { params(repo_path: String).returns(T.nilable(T::Array[Core::PR])) }
      def fetch_history(repo_path)
        Integrations::GitHub.fetch_pr_history(repo_path)
      rescue StandardError => e
        Log.debug "inventory: PR history unavailable (#{e.message})"
        nil
      end

      # An OPEN PR always wins over a closed one on the same branch; otherwise
      # the most recently updated one does.
      sig { params(prs: T::Array[Core::PR]).returns(T::Hash[String, Core::PR]) }
      def index_prs(prs)
        prs.each_with_object({}) do |pr, h|
          next unless pr.branch

          current = h[pr.branch]
          h[pr.branch] = pr if current.nil? ||
                               (pr.github_state == 'OPEN' && current.github_state != 'OPEN') ||
                               (current.github_state != 'OPEN' && pr.updated_at.to_s > current.updated_at.to_s)
        end
      end

      sig { params(store: T.nilable(Store)).returns(T::Set[String]) }
      def auto_branches_from(store)
        return Set.new unless store

        Set.new(store.all_backlog.filter_map(&:branch))
      rescue StandardError
        Set.new
      end

      # A worktree is nightshift's if the branch says so, if the directory says
      # so, or if the backlog claims it. The branch prefix alone is not enough:
      # a skill can rename its branch (perf/expert-spec lives in
      # auto-test-optimization-batch-623d3f73) and the worktree then escapes
      # every `auto/`-prefixed filter.
      sig { params(path: T.nilable(String), branch: T.nilable(String), auto_branches: T::Set[String]).returns(WorkItemOrigin) }
      def origin_of(path, branch, auto_branches)
        return WorkItemOrigin::Auto if branch && (branch.start_with?('auto/') || auto_branches.include?(branch))
        return WorkItemOrigin::Auto if path && File.basename(path).start_with?('auto-')

        WorkItemOrigin::Manual
      end

      sig do
        params(worktrees: T::Array[WorktreeEntry], repo_path: String,
               by_branch: T::Hash[String, Core::PR],
               auto_branches: T::Set[String]).returns(T::Array[WorkItem])
      end
      def worktree_items(worktrees, repo_path, by_branch, auto_branches)
        worktrees.map do |entry|
          pr = entry.branch && by_branch[entry.branch]
          missing = !entry.exists?
          action, reason = worktree_verdict(entry, pr, missing)

          WorkItem.new(
            kind: WorkItemKind::Worktree,
            label: entry.label,
            origin: origin_of(entry.path, entry.branch, auto_branches),
            repo: repo_path,
            path: entry.path,
            branch: entry.branch,
            pr_number: pr&.number,
            pr_state: pr&.state,
            github_state: pr&.github_state,
            locked: entry.locked,
            detached: entry.detached,
            missing_dir: missing,
            unknown_state: missing,
            cleanup: action,
            reason: reason
          )
        end
      end

      sig { params(entry: WorktreeEntry, pr: T.nilable(Core::PR), missing: T::Boolean).returns([T.nilable(CleanupAction), T.nilable(String)]) }
      def worktree_verdict(entry, pr, missing)
        return [CleanupAction::PruneAdmin, 'dossier disparu, entrée admin encore là'] if missing
        return [nil, 'worktree verrouillé'] if entry.locked
        return [nil, nil] unless pr

        case pr.github_state
        when 'MERGED' then [CleanupAction::CloseWorktree, "PR ##{pr.number} mergée"]
        when 'CLOSED' then [CleanupAction::CloseWorktree, "PR ##{pr.number} fermée"]
        else [nil, nil]
        end
      end

      # The PRs the reconciler never saw: open on GitHub, no worktree here.
      sig do
        params(prs: T::Array[Core::PR], worktrees: T::Array[WorktreeEntry],
               repo_path: String, auto_branches: T::Set[String]).returns(T::Array[WorkItem])
      end
      def pr_items(prs, worktrees, repo_path, auto_branches)
        covered = Set.new(worktrees.filter_map(&:branch))

        prs.select { |pr| pr.github_state == 'OPEN' && pr.branch && !covered.include?(pr.branch) }
           .sort_by { |pr| -pr.number.to_i }
           .map do |pr|
          WorkItem.new(
            kind: WorkItemKind::Pr,
            label: pr.branch.to_s,
            origin: origin_of(nil, pr.branch, auto_branches),
            repo: repo_path,
            branch: pr.branch,
            pr_number: pr.number,
            pr_state: pr.state,
            github_state: pr.github_state,
            reason: 'pas de worktree local'
          )
        end
      end

      sig { params(repo_path: String).returns(T::Array[WorkItem]) }
      def ghost_items(repo_path)
        Integrations::Worktree.ghost_dirs(repo_path).map do |ghost|
          dangling = ghost[:kind] == :dangling_git
          WorkItem.new(
            kind: WorkItemKind::GhostDir,
            label: File.basename(ghost[:path]),
            origin: File.basename(ghost[:path]).start_with?('auto-') ? WorkItemOrigin::Auto : WorkItemOrigin::Manual,
            repo: repo_path,
            path: ghost[:path],
            unknown_state: dangling,
            cleanup: CleanupAction::RemoveDir,
            reason: dangling ? 'checkout orphelin, .git pointe dans le vide' : 'reliquat de worktree supprimé'
          )
        end
      end

      sig { params(repo_path: String).returns(T::Array[WorkItem]) }
      def orphan_db_items(repo_path)
        names = Integrations::Worktree.orphan_databases(repo_path)
        sizes = Integrations::Worktree.database_sizes(names)

        names.map do |name|
          WorkItem.new(
            kind: WorkItemKind::OrphanDb,
            label: name,
            origin: name.start_with?('tps_test_auto_') ? WorkItemOrigin::Auto : WorkItemOrigin::Manual,
            repo: repo_path,
            size_bytes: sizes[name] || 0,
            cleanup: CleanupAction::DropDatabase,
            reason: 'aucun worktree ne la revendique'
          )
        end
      end

      # Branches already merged into base and not checked out anywhere. `-d`
      # will refuse anything else, so this list is advisory, never load-bearing.
      sig do
        params(repo_path: String, entries: T::Array[WorktreeEntry],
               by_branch: T::Hash[String, Core::PR], base: String).returns(T::Array[WorkItem])
      end
      def stale_branch_items(repo_path, entries, by_branch, base)
        checked_out = Set.new(entries.filter_map(&:branch))

        Integrations::Git.merged_branches(repo_path, base: base)
                         .reject { |b| checked_out.include?(b) }
                         .map do |branch|
          pr = by_branch[branch]
          WorkItem.new(
            kind: WorkItemKind::StaleBranch,
            label: branch,
            origin: branch.start_with?('auto/') ? WorkItemOrigin::Auto : WorkItemOrigin::Manual,
            repo: repo_path,
            branch: branch,
            pr_number: pr&.number,
            github_state: pr&.github_state,
            cleanup: CleanupAction::DeleteBranch,
            reason: "déjà contenue dans #{base}"
          )
        end
      end

      # Ask git and du about the candidates. Only the items the doctor could act
      # on are probed — questioning 83 worktrees costs real seconds.
      #
      # git is questioned for registered worktrees only. Running `git -C` inside
      # a ghost directory would walk up and answer about whatever repository
      # happens to contain it, which is worse than not asking.
      sig { params(items: T::Array[WorkItem]).void }
      def enrich!(items)
        targets = items.each_with_index.select do |item, _|
          item.cleanup && item.path && !item.missing_dir
        end

        targets.each_slice(CONCURRENCY) do |slice|
          slice.map do |item, index|
            Thread.new do
              path = T.must(item.path)
              probe = item.kind == WorkItemKind::Worktree && !item.unknown_state
              dirty = probe ? Integrations::Git.dirty?(path) : false
              unpushed = probe ? Integrations::Git.unpushed?(path) : false
              [index, dirty, unpushed, Integrations::Git.dir_size(path)]
            end
          end.each do |thread|
            index, dirty, unpushed, size = thread.value
            item = T.must(items[index])
            item.dirty = dirty == true
            item.unpushed = unpushed == true
            # nil is not false: if git could not answer, the item stops being
            # a cleanup candidate rather than becoming a silent deletion.
            item.unknown_state = item.unknown_state || dirty.nil? || unpushed.nil?
            item.size_bytes = size
          end
        end
      end
    end
  end
end
