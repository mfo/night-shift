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

    sig { params(store: Core::Store, renderer: UI::Renderer, worktree_branches: T.nilable(T::Set[String])).void }
    def initialize(store:, renderer:, worktree_branches: nil)
      @store = store
      @renderer = renderer
      @worktree_branches = worktree_branches
    end


    sig { params(prs: T::Array[Core::PR]).void }
    def reconcile(prs)
      branches = @worktree_branches || list_worktree_branches
      active_prs = prs.select { |pr| branches.include?(pr.branch) }

      active_prs.each do |pr|
        result = @store.reconcile_pr(pr)

        @renderer.show_comments(pr) if result[:comment_delta].positive?

        if result[:changed] && !@store.locked?(pr.number, kind: result[:new_state].serialize)
          on_transition(pr, result[:old_state], result[:new_state])
        end

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
      return unless config&.dig(:scan_proc)

      completed = @store.db[:backlog_items]
                        .where(skill: skill_name, status: Core::Store::DONE_S).count
      return unless completed.positive? && (completed % 5).zero?

      Log.info "triggering reprioritize for #{skill_name} (#{completed} completed)"
      CI::Reprioritizer.run(skill_name, store: @store)
    end

    sig { void }
    def pick_next_items
      repo_path = Nightshift.repo_path
      Nightshift.skills.each do |skill_name, skill_config|
        next if @store.active_for_skill?(skill_name)

        batch_size = (skill_config[:batch_size] || 1).to_i.clamp(1, 20)

        if batch_size > 1
          items = @store.claim_batch(skill_name, batch_size)
          next if items.empty?

          valid, stale = items.partition do |bi|
            system('git', '-C', repo_path, 'cat-file', '-e', "HEAD:#{bi.item}", err: File::NULL)
          end
          stale.each { |bi| @store.update_backlog_status(bi, BacklogStatus::Skipped, failure_reason: FailureReason::FileNotFound) }
          next if valid.empty?

          launch_batch(skill_name, valid)
        else
          backlog_item = @store.claim_next(skill_name)
          next unless backlog_item

          unless system('git', '-C', repo_path, 'cat-file', '-e', "HEAD:#{backlog_item.item}", err: File::NULL)
            @store.update_backlog_status(backlog_item, BacklogStatus::Skipped, failure_reason: FailureReason::FileNotFound)
            next
          end

          launch_skill(skill_name, backlog_item)
        end
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

      Integrations::Worktree.cleanup(branch)

      unless system('git', '-C', repo_path, 'worktree', 'add', wt_path, 'main', '-b', branch)
        @store.update_backlog_status(backlog_item, BacklogStatus::Failed, failure_reason: FailureReason::WorktreeError)
        return
      end
      @store.update_backlog_status(backlog_item, BacklogStatus::Running, branch: branch)

      %w[log tmp].each { |d| FileUtils.mkdir_p(File.join(wt_path, d)) }
      Dir.glob(File.join(wt_path, 'log', '*.log')).each { |f| File.truncate(f, 0) }

      skill_config = Nightshift.skills[skill_name] || {}
      port = skill_config[:port]

      server_cmd = if skill_config[:needs_server] && port
        File.write(File.join(wt_path, '.env.development.local'),
                   "PORT=#{port}\nAPP_HOST=\"localhost:#{port}\"\n")
        "PORT=#{port} overmind start -f Procfile.sidekiq.dev"
      end

      win_id = @renderer.launch_skill_window(
        name: "🤖 #{skill_name}-#{slug}",
        path: wt_path,
        branch: branch,
        server_cmd: server_cmd
      )

      env_prefix = port ? "PORT=#{port}" : ''
      skill_cmd = "#{env_prefix} #{Nightshift.binstub_cmd} skill-run #{skill_name} #{Shellwords.escape(backlog_item.item)}".strip
      @renderer.send_keys(target: "#{win_id}.0", command: skill_cmd)
    end

    sig { params(skill_name: String, backlog_items: T::Array[Core::BacklogItem]).void }
    def launch_batch(skill_name, backlog_items)
      require 'shellwords'
      repo_path = Nightshift.repo_path
      batch_id = backlog_items.first.batch_id
      branch = "auto/#{skill_name}/batch-#{batch_id[0, 8]}"
      wt_dir = "auto-#{skill_name}-batch-#{batch_id[0, 8]}"
      wt_path = File.join(File.dirname(repo_path), wt_dir)

      Integrations::Worktree.cleanup(branch)

      unless system('git', '-C', repo_path, 'worktree', 'add', wt_path, 'main', '-b', branch)
        backlog_items.each { |bi| @store.update_backlog_status(bi, BacklogStatus::Failed, failure_reason: FailureReason::WorktreeError) }
        return
      end
      backlog_items.each { |bi| @store.update_backlog_status(bi, BacklogStatus::Running, branch: branch) }

      %w[log tmp].each { |d| FileUtils.mkdir_p(File.join(wt_path, d)) }
      Dir.glob(File.join(wt_path, 'log', '*.log')).each { |f| File.truncate(f, 0) }

      skill_config = Nightshift.skills[skill_name] || {}
      port = skill_config[:port]

      server_cmd = if skill_config[:needs_server] && port
        File.write(File.join(wt_path, '.env.development.local'),
                   "PORT=#{port}\nAPP_HOST=\"localhost:#{port}\"\n")
        "PORT=#{port} overmind start -f Procfile.sidekiq.dev"
      end

      win_id = @renderer.launch_skill_window(
        name: "🤖 #{skill_name}-batch-#{batch_id[0, 8]}",
        path: wt_path,
        branch: branch,
        server_cmd: server_cmd
      )

      env_prefix = port ? "PORT=#{port}" : ''
      skill_cmd = "#{env_prefix} #{Nightshift.binstub_cmd} skill-run-batch #{skill_name} #{batch_id}".strip
      @renderer.send_keys(target: "#{win_id}.0", command: skill_cmd)
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
