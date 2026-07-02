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
      reconcile_skills(prs)
    end

    sig { params(prs: T::Array[Core::PR]).void }
    def reconcile_skills(prs)
      active_branches = @worktree_branches || list_worktree_branches
      health_check(prs, active_branches)
      cleanup_orphan_worktrees(active_branches)
      pick_next_items
    end

    sig { params(prs: T::Array[Core::PR], active_branches: T::Set[String]).void }
    def health_check(prs, active_branches)
      pr_by_branch = prs.each_with_object({}) { |pr, h| h[pr.branch] = pr }

      @store.all_backlog.each do |backlog_item|
        case backlog_item.status
        when BacklogStatus::PrOpen
          pr = pr_by_branch[backlog_item.branch]
          handle_done(backlog_item) if pr&.github_state == 'MERGED'
          handle_closed(backlog_item) if pr&.github_state == 'CLOSED'
        when BacklogStatus::Running
          if backlog_item.branch.nil? || backlog_item.branch.empty?
            recover_zombie(backlog_item)
            next
          end

          is_zombie = if !active_branches.include?(backlog_item.branch)
                        true
                      else
                        wt_path = Integrations::Worktree.path_for_branch(backlog_item.branch)
                        wt_path && zombie_process?(wt_path)
                      end

          recover_zombie(backlog_item) if is_zombie
        end
      end
    end

    private

    def cleanup_orphan_worktrees(active_branches)
      running_branches = Set.new(
        @store.all_backlog
              .select { |bi| bi.status == BacklogStatus::Running && bi.branch }
              .map(&:branch)
      )
      pr_open_branches = Set.new(
        @store.all_backlog
              .select { |bi| bi.status == BacklogStatus::PrOpen && bi.branch }
              .map(&:branch)
      )
      open_pr_branches = Set.new(
        @store.all_prs(github_state: 'OPEN').map { |pr| pr[:branch] }.compact
      )

      active_branches.each do |branch|
        next unless branch.start_with?('auto/')
        next if running_branches.include?(branch)
        next if pr_open_branches.include?(branch)
        next if open_pr_branches.include?(branch)

        wt_path = Integrations::Worktree.path_for_branch(branch)
        next if wt_path && !zombie_process?(wt_path)

        Log.info "orphan worktree detected: #{branch} — cleaning up"
        Integrations::Worktree.cleanup(branch)
        @renderer.close_worktree(branch)
      end
    end

    sig { params(backlog_item: Core::BacklogItem).void }
    def handle_done(backlog_item)
      @store.update_backlog_status(backlog_item, BacklogStatus::Done)
      Integrations::Worktree.cleanup(backlog_item.branch)
      @renderer.close_worktree(backlog_item.branch)

      maybe_reprioritize(backlog_item.skill)
    end

    sig { params(backlog_item: Core::BacklogItem).void }
    def handle_closed(backlog_item)
      @store.update_backlog_status(backlog_item, BacklogStatus::Skipped,
                                   failure_reason: FailureReason::ManualClose, branch: nil)
      Integrations::Worktree.cleanup(backlog_item.branch)
      @renderer.close_worktree(backlog_item.branch)
      Log.info "PR closed without merge — skipped #{backlog_item.item}"
    end

    def zombie_process?(worktree_path)
      pid_path = File.join(worktree_path, 'tmp', 'nightshift.pid')
      return true unless File.exist?(pid_path)

      pid = File.read(pid_path).strip.to_i
      return true if pid.zero?

      !process_alive?(pid)
    end

    def process_alive?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end

    def recover_zombie(backlog_item)
      retry_count = backlog_item.retry_count.to_i
      branch = backlog_item.branch

      if branch && !branch.empty?
        # If a PR was already created on this branch, promote to pr_open instead of resetting
        open_pr = @store.all_prs(github_state: 'OPEN').find { |pr| pr[:branch] == branch }
        if open_pr
          Log.info "zombie recovered: #{backlog_item.item} — PR ##{open_pr[:number]} already open, promoting to pr_open"
          @store.update_backlog_status(backlog_item, BacklogStatus::PrOpen,
                                       pr_number: open_pr[:number], branch: branch)
          return
        end

        # Only cleanup worktree if no other items are still using this branch
        siblings = @store.all_backlog.count { |bi| bi.id != backlog_item.id && bi.branch == branch }
        if siblings.zero?
          Integrations::Worktree.cleanup(branch)
          @renderer.close_worktree(branch)
        end
      end

      if retry_count < CI::Judge::MAX_RETRIES
        Log.info "zombie detected: #{backlog_item.item} — resetting to pending (retry #{retry_count + 1}/#{CI::Judge::MAX_RETRIES})"
        @store.update_backlog_status(backlog_item, BacklogStatus::Pending,
                                     branch: nil, failure_reason: nil)
        @store.db[:backlog_items].where(id: backlog_item.id)
              .update(retry_count: Sequel.expr(:retry_count) + 1)
      else
        Log.info "zombie exhausted: #{backlog_item.item} — skipping"
        @store.update_backlog_status(backlog_item, BacklogStatus::Skipped,
                                     failure_reason: FailureReason::ZombieExhausted)
      end
    end

    sig { params(skill_name: String).void }
    def maybe_reprioritize(skill_name)
      return unless BacklogSources::REGISTRY.key?(skill_name)

      completed = @store.db[:backlog_items]
                        .where(skill: skill_name, status: Core::Store::DONE_S).count
      return unless completed.positive? && (completed % 5).zero?

      Log.info "triggering reprioritize for #{skill_name} (#{completed} completed)"
      CI::Reprioritizer.run(skill_name, store: @store)
    end

    sig { void }
    def pick_next_items
      repo_path = Nightshift.repo_path

      # Count actually-running items per backend (PrOpen doesn't consume compute)
      active_by_backend = Hash.new(0)
      @store.all_backlog.each do |bi|
        next unless bi.status == BacklogStatus::Running

        backend = Nightshift.backend_for(bi.skill)
        active_by_backend[backend.harness] += 1
      end

      BacklogSources::REGISTRY.each_key do |skill_name|
        next if @store.active_for_skill?(skill_name)

        backend = Nightshift.backend_for(skill_name)
        next if active_by_backend[backend.harness] >= backend.concurrency

        skill_config = Nightshift.skills[skill_name] || {}
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
          active_by_backend[backend.harness] += 1
        else
          backlog_item = @store.claim_next(skill_name)
          next unless backlog_item

          unless system('git', '-C', repo_path, 'cat-file', '-e', "HEAD:#{backlog_item.item}", err: File::NULL)
            @store.update_backlog_status(backlog_item, BacklogStatus::Skipped, failure_reason: FailureReason::FileNotFound)
            next
          end

          launch_skill(skill_name, backlog_item)
          active_by_backend[backend.harness] += 1
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

      server_cmd, env_prefix = setup_server(skill_name, wt_path)

      win_id = @renderer.launch_skill_window(
        name: "🤖 #{skill_name}-#{slug}",
        path: wt_path,
        branch: branch,
        server_cmd: server_cmd
      )

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

      server_cmd, env_prefix = setup_server(skill_name, wt_path)

      win_id = @renderer.launch_skill_window(
        name: "🤖 #{skill_name}-batch-#{batch_id[0, 8]}",
        path: wt_path,
        branch: branch,
        server_cmd: server_cmd
      )

      skill_cmd = "#{env_prefix} #{Nightshift.binstub_cmd} skill-run-batch #{skill_name} #{batch_id}".strip
      @renderer.send_keys(target: "#{win_id}.0", command: skill_cmd)
    end

    sig { params(skill_name: String, wt_path: String).returns([T.nilable(String), String]) }
    def setup_server(skill_name, wt_path)
      skill_config = Nightshift.skills[skill_name] || {}
      port = skill_config[:port]
      return [nil, ''] unless skill_config[:needs_server] && port

      vite_port = skill_config[:vite_port]
      env_lines = ["PORT=#{port}", "APP_HOST=\"localhost:#{port}\""]
      env_lines << "VITE_RUBY_PORT=#{vite_port}" if vite_port
      File.write(File.join(wt_path, '.env.development.local'), env_lines.join("\n") + "\n")

      env_prefix = "PORT=#{port}"
      env_prefix += " VITE_RUBY_PORT=#{vite_port}" if vite_port
      server_cmd = "#{env_prefix} overmind start -f Procfile.sidekiq.dev"

      [server_cmd, env_prefix]
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
      in [_, PRState::Merged | PRState::Deployed | PRState::Closed]
        @renderer.propose_cleanup(pr)
      else
        # noop
      end
    end
  end
end
