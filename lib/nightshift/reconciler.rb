# frozen_string_literal: true
# typed: false

require 'open3'

module Nightshift
  #
  # Reconciler — Main watch loop
  #
  # Runs every N seconds: fetches PRs, diffs against stored state,
  # fires transition handlers (autofix on red, merge on approved,
  # cleanup on merged), and picks next backlog items to launch.
  # Only reconciles PRs matching a local worktree branch.
  #
  class Reconciler
    extend T::Sig

    sig { params(store: Core::Store, renderer: T.untyped, worktree_branches: T.nilable(T::Set[String])).void }
    def initialize(store:, renderer:, worktree_branches: nil)
      @store = store
      @renderer = renderer
      @worktree_branches = worktree_branches
    end


    sig { params(prs: T::Array[Core::PR]).void }
    def reconcile(prs)
      # Worktree-centric: only reconcile PRs that match a local worktree
      branches = @worktree_branches || list_worktree_branches
      active_prs = prs.select { |pr| branches.include?(pr.branch) }

      active_prs.each do |pr|
        result = @store.reconcile_pr(pr)

        # 1. Comments FIRST — show if new comments detected
        @renderer.show_comments(pr) if result[:comment_delta].positive?

        # 2. State transitions SECOND
        if result[:changed] && !@store.locked?(pr.number, kind: result[:new_state].serialize)
          on_transition(pr, result[:old_state], result[:new_state])
        end

        # 3. Window update LAST
        @renderer.update_window(pr)
      end
      reconcile_skills(active_prs)
    end

    sig { params(prs: T::Array[Core::PR]).void }
    def reconcile_skills(prs)
      pr_by_branch = prs.each_with_object({}) { |pr, h| h[pr.branch] = pr }
      active_branches = @worktree_branches || list_worktree_branches

      @store.all_backlog.each do |backlog_item|
        case backlog_item.status
        when BacklogStatus::PrOpen
          pr = pr_by_branch[backlog_item.branch]
          handle_done(backlog_item) if pr&.github_state == 'MERGED'
        when BacklogStatus::Running
          # Zombie recovery: running item but worktree gone
          if backlog_item.branch && !active_branches.include?(backlog_item.branch)
            retry_count = backlog_item.retry_count.to_i
            if retry_count < CI::Judge::MAX_RETRIES
              @store.update_backlog_status(backlog_item, BacklogStatus::Pending,
                                           branch: nil, failure_reason: nil)
              @store.db[:backlog_items].where(id: backlog_item.id)
                    .update(retry_count: Sequel.expr(:retry_count) + 1)
            else
              @store.update_backlog_status(backlog_item, BacklogStatus::Skipped,
                                           failure_reason: FailureReason::ZombieExhausted)
            end
          end
        end
      end

      pick_next_items
    end

    private

    sig { params(backlog_item: Core::BacklogItem).void }
    def handle_done(backlog_item)
      @store.update_backlog_status(backlog_item, BacklogStatus::Done)
      Integrations::Worktree.cleanup(backlog_item.branch)
      @renderer.close_worktree(backlog_item.branch)

      maybe_reprioritize(backlog_item.skill)
    end

    sig { params(skill_name: String).void }
    def maybe_reprioritize(skill_name)
      config = Nightshift.skills[skill_name]
      return unless config&.dig(:scan_proc) # only for skills with dynamic scan

      completed = @store.db[:backlog_items]
                        .where(skill: skill_name, status: Core::Store::DONE_S).count
      return unless completed.positive? && (completed % 5).zero?

      Log.info "triggering reprioritize for #{skill_name} (#{completed} completed)"
      CI::Reprioritizer.run(skill_name, store: @store)
    end

    sig { void }
    def pick_next_items
      repo_path = Nightshift.repo_path
      Nightshift.skills.each_key do |skill_name|
        next if @store.active_for_skill?(skill_name)

        backlog_item = @store.claim_next(skill_name)
        next unless backlog_item

        # Guard: skip if the target file no longer exists on main
        unless system('git', '-C', repo_path, 'cat-file', '-e', "HEAD:#{backlog_item.item}", err: File::NULL)
          @store.update_backlog_status(backlog_item, BacklogStatus::Skipped, failure_reason: FailureReason::FileNotFound)
          next
        end

        launch_skill(skill_name, backlog_item)
      end
    end

    sig { params(skill_name: String, backlog_item: Core::BacklogItem).void }
    def launch_skill(skill_name, backlog_item)
      require 'shellwords'
      repo_path = Nightshift.repo_path
      slug = short_slug(backlog_item.item, skill_name: skill_name)
      branch = "auto/#{skill_name}/#{slug}"
      wt_dir = "auto-#{skill_name}-#{slug}"
      wt_path = File.join(File.dirname(repo_path), wt_dir)

      # Clean up stale branch/dir from previous failed attempts
      Integrations::Worktree.cleanup(branch)

      unless system('git', '-C', repo_path, 'worktree', 'add', wt_path, 'main', '-b', branch)
        @store.update_backlog_status(backlog_item, BacklogStatus::Failed, failure_reason: FailureReason::WorktreeError)
        return
      end
      @store.update_backlog_status(backlog_item, BacklogStatus::Running, branch: branch)

      # Ensure gitignored dirs exist + clean logs for fresh investigation
      %w[log tmp].each { |d| FileUtils.mkdir_p(File.join(wt_path, d)) }
      Dir.glob(File.join(wt_path, 'log', '*.log')).each { |f| File.truncate(f, 0) }

      session = ENV.fetch('NIGHTSHIFT_SESSION')
      skill_config = Nightshift.skills[skill_name] || {}

      # Reuse existing window if one already has this branch (e.g. from attach)
      win_id = find_window_by_branch(session, branch)
      unless win_id
        win_id, = Open3.capture2('tmux', 'new-window', '-t', session, '-n', "🤖 #{skill_name}-#{slug}",
                                 '-c', wt_path, '-P', '-F', '#{window_id}')
        win_id = win_id.strip
        system('tmux', 'set-option', '-w', '-t', win_id, '@branch', branch)
      end

      # Launch server in background pane if skill needs it
      port = skill_config[:port]
      if skill_config[:needs_server] && port
        File.write(File.join(wt_path, '.env.development.local'),
                   "PORT=#{port}\nAPP_HOST=\"localhost:#{port}\"\n")
        system('tmux', 'split-window', '-t', win_id, '-v', '-l', '20%',
               '-c', wt_path)
        system('tmux', 'send-keys', '-t', "#{win_id}.1",
               "PORT=#{port} overmind start -f Procfile.sidekiq.dev", 'Enter')
        system('tmux', 'select-pane', '-t', "#{win_id}.0")
      end

      # Send skill-run command
      env_prefix = port ? "PORT=#{port}" : ''
      skill_cmd = "#{env_prefix} #{Nightshift.binstub_cmd} skill-run #{skill_name} #{Shellwords.escape(backlog_item.item)}".strip
      system('tmux', 'send-keys', '-t', "#{win_id}.0", skill_cmd, 'Enter')
    end

    sig { params(session: String, branch: String).returns(T.nilable(String)) }
    def find_window_by_branch(session, branch)
      return nil unless branch

      out, _, status = Open3.capture3(
        'tmux', 'list-windows', '-t', session,
        '-F', '#{window_id} #{@branch}'
      )
      return nil unless status.success?

      out.each_line do |line|
        win_id, win_branch = line.strip.split(' ', 2)
        return win_id if win_branch == branch
      end
      nil
    end

    sig { returns(T::Set[String]) }
    def list_worktree_branches
      Integrations::Worktree.branches
    end

    sig { params(path: String, skill_name: T.nilable(String)).returns(String) }
    def short_slug(path, skill_name: nil)
      Nightshift.short_slug(path, skill_name: skill_name)
    end

    sig { params(pr: Core::PR, old_state: T.nilable(PRState), new_state: PRState).void }
    def on_transition(pr, old_state, new_state)
      case [old_state, new_state]
      in [_, PRState::CiRed]
        @renderer.autofix(pr)
      in [_, PRState::Approved]
        @renderer.propose_merge(pr)
      in [PRState::CiRed, PRState::CiGreen]
        @renderer.notify_fixed(pr)
      in [_, PRState::Merged | PRState::Deployed]
        @renderer.propose_cleanup(pr)
      else
        # noop
      end
    end
  end
end
