# frozen_string_literal: true
# typed: false

require 'open3'

module Nightshift
  module Skills
    #
    # Pipeline — Full skill execution lifecycle
    #
    # Orchestrates: run skill → on success, push + create PR → pr_open.
    # On failure, invokes the Judge for a verdict, then either retries
    # (with optional patterns.md patch) or skips the item.
    #
    class Pipeline
      extend T::Sig

      sig { params(store: Core::Store).void }
      def initialize(store:)
        @store = store
      end

      sig { params(backlog_item: Core::BacklogItem).void }
      def execute(backlog_item)
        skill = backlog_item.skill
        item_path = backlog_item.item
        context = backlog_item.context
        branch = backlog_item.branch
        worktree_path = Integrations::Worktree.path_for_branch(branch)

        unless worktree_path
          @store.update_backlog_status(backlog_item, BacklogStatus::Failed,
                                       failure_reason: FailureReason::WorktreeError)
          Log.error "no worktree found for branch #{branch}"
          return
        end

        write_pid_file(worktree_path)

        result = Runner.run(skill, item: item_path, worktree_path: worktree_path, context: context)

        unless result.success
          handle_failure(backlog_item, result)
          return
        end

        # Check pr-description.md
        desc_path = File.join(worktree_path, 'pr-description.md')
        unless File.exist?(desc_path)
          no_desc_result = RunnerResult.new(
            success: result.success, failure_reason: FailureReason::NoPrDescription.serialize,
            log_path: result.log_path, turns_used: result.turns_used,
            files_changed: result.files_changed
          )
          handle_failure(backlog_item, no_desc_result)
          return
        end

        push_and_create_pr(backlog_item, worktree_path, result)
      ensure
        remove_pid_file(worktree_path) if worktree_path
      end

      sig { params(backlog_items: T::Array[Core::BacklogItem]).void }
      def execute_batch(backlog_items)
        return if backlog_items.empty?

        first = backlog_items.first
        branch = first.branch
        skill = first.skill
        worktree_path = Integrations::Worktree.path_for_branch(branch)

        unless worktree_path
          backlog_items.each do |bi|
            @store.update_backlog_status(bi, BacklogStatus::Failed,
                                         failure_reason: FailureReason::WorktreeError)
          end
          Log.error "no worktree found for branch #{branch}"
          return
        end

        write_pid_file(worktree_path)

        committed = []
        failed = []

        desc_path = File.join(worktree_path, 'pr-description.md')
        desc_dir = File.join(worktree_path, 'tmp', 'batch-descriptions')
        FileUtils.mkdir_p(desc_dir)

        backlog_items.each_with_index do |backlog_item, idx|
          Log.info "batch #{committed.size + 1}/#{backlog_items.size}: #{backlog_item.item}"

          # Clean pr-description.md before each item so stale descriptions don't leak
          FileUtils.rm_f(desc_path)

          result = Runner.run(skill, item: backlog_item.item, worktree_path: worktree_path,
                                     context: backlog_item.context)

          if result.success
            # Persist pr-description.md to disk (survives crash, not just RAM)
            if File.exist?(desc_path)
              FileUtils.cp(desc_path, File.join(desc_dir, "#{idx}.md"))
            end
            committed << { backlog_item: backlog_item, result: result }
            @store.record_cycle(backlog_item, verdict: VerdictName::Success, outcome: 'committed',
                                              log_path: result.log_path, turns: result.turns_used)
          else
            failed << { backlog_item: backlog_item, result: result }
            handle_failure(backlog_item, result, cleanup_worktree: false)
          end
        end

        if committed.empty?
          Log.warn "batch: all #{backlog_items.size} items failed"
          return
        end

        # Check that at least one item produced a pr-description
        unless Dir.glob(File.join(desc_dir, '*.md')).any?
          last = committed.last
          no_desc_result = RunnerResult.new(
            success: true, failure_reason: FailureReason::NoPrDescription.serialize,
            log_path: last[:result].log_path, turns_used: last[:result].turns_used,
            files_changed: last[:result].files_changed
          )
          committed.each { |c| handle_failure(c[:backlog_item], no_desc_result, cleanup_worktree: false) }
          return
        end

        push_and_create_pr_batch(committed, worktree_path, branch)
      ensure
        remove_pid_file(worktree_path) if worktree_path
      end

      sig { params(backlog_item: Core::BacklogItem, result: RunnerResult, cleanup_worktree: T::Boolean).void }
      def handle_failure(backlog_item, result, cleanup_worktree: true)
        skill = backlog_item.skill
        item_path = backlog_item.item
        branch = backlog_item.branch
        failure_reason = result.failure_reason
        retry_count = backlog_item.retry_count.to_i

        # Rate limit: skip judge (would also be rate-limited), backoff 30min
        if failure_reason == FailureReason::RateLimited.serialize
          Log.warn 'rate limited — backoff 30min'
          @store.record_cycle(backlog_item, verdict: VerdictName::RateLimited,
                                            root_cause: 'rate_limited', log_path: result.log_path,
                                            turns: result.turns_used)
          Integrations::Worktree.cleanup(branch) if cleanup_worktree
          @store.update_backlog_status(backlog_item, BacklogStatus::Pending,
                                       branch: nil, failure_reason: nil,
                                       retry_after: Time.now.to_i + 1800)
          return
        end

        Log.error "skill failed (#{failure_reason}) — invoking judge"

        # Judge: analyze the failure
        verdict = CI::Judge.evaluate(skill, item: item_path,
                                            log_path: result.log_path,
                                            failure_reason: failure_reason)

        Log.info "┌─ verdict: #{verdict.verdict.serialize} (confidence: #{verdict.confidence})"
        Log.info "│  cause: #{verdict.root_cause}"
        Log.info "└─ patch: #{verdict.suggested_patch ? 'yes' : 'none'}"

        # Record the cycle
        @store.record_cycle(backlog_item, verdict: verdict.verdict,
                                          root_cause: verdict.root_cause,
                                          suggested_patch: verdict.suggested_patch,
                                          confidence: verdict.confidence,
                                          log_path: result.log_path, turns: result.turns_used)

        # Store infra suggestion if infra_error
        if verdict.verdict == VerdictName::InfraError && verdict.root_cause
          @store.add_infra_suggestion(skill: skill, description: verdict.root_cause,
                                      source: 'judge', backlog_item_id: backlog_item.id)
          Log.info '💡 infra suggestion enregistree'
        end

        # Decide: retry or stop
        if CI::Judge.retryable?(verdict, retry_count)
          # Apply patch if skill_defect with high confidence
          if verdict.verdict == VerdictName::SkillDefect && verdict.suggested_patch && verdict.confidence >= 0.75
            sha = apply_patch(skill, verdict.suggested_patch)
            if sha
              cycle_id = @store.last_cycle_id(backlog_item)
              @store.update_cycle_patch_sha(cycle_id, sha) if cycle_id
            end
          elsif verdict.verdict == VerdictName::SkillDefect && verdict.suggested_patch && verdict.confidence >= 0.5
            Log.warn "low-confidence patch (#{verdict.confidence}) — skipping auto-apply, needs manual review"
          end

          Integrations::Worktree.cleanup(branch) if cleanup_worktree

          # Reset to pending — the reconciler will re-launch on next cycle
          @store.update_backlog_status(backlog_item, BacklogStatus::Pending,
                                       branch: nil, failure_reason: nil,
                                       last_verdict: verdict.verdict)
          @store.db[:backlog_items].where(id: backlog_item.id)
                .update(retry_count: Sequel.expr(:retry_count) + 1)
          Log.info "🔄 reset to pending (retry #{retry_count + 1}/#{CI::Judge::MAX_RETRIES}) — reconciler will re-launch"
        else
          Runner.analyze_run(skill, item: item_path, log_path: result.log_path,
                             outcome: :failure, failure_reason: failure_reason)

          failure = retry_count >= CI::Judge::MAX_RETRIES ? FailureReason::AutolearnExhausted : verdict.verdict

          Integrations::Worktree.cleanup(branch) if cleanup_worktree

          @store.update_backlog_status(backlog_item, BacklogStatus::Skipped,
                                       failure_reason: failure, branch: nil,
                                       last_verdict: verdict.verdict)
          Log.info "⏭ skipped (#{failure.serialize})"
        end
      end

      def push_and_create_pr(backlog_item, worktree_path, result)
        branch = backlog_item.branch

        # Read pr-description.md BEFORE removing it from git
        desc_path = File.join(worktree_path, 'pr-description.md')
        raw = File.read(desc_path)
        title, body = parse_pr_description(raw)

        remove_pr_description(worktree_path)

        unless system('git', 'push', '-u', 'origin', branch, chdir: worktree_path)
          @store.update_backlog_status(backlog_item, BacklogStatus::Failed,
                                       failure_reason: FailureReason::PushError)
          Log.error "push failed for #{branch}"
          return
        end

        pr_number = create_gh_pr(branch, title, body, worktree_path)
        @store.update_backlog_status(backlog_item, BacklogStatus::PrOpen,
                                     pr_number: pr_number, branch: branch)
        Log.info "PR ##{pr_number} created"

        @store.record_cycle(backlog_item, verdict: VerdictName::Success, outcome: 'improved',
                                          log_path: result.log_path, turns: result.turns_used)

        Runner.analyze_run(backlog_item.skill, item: backlog_item.item,
                           log_path: result.log_path, outcome: :success)
      end

      def push_and_create_pr_batch(committed, worktree_path, branch)
        title, body = combine_batch_descriptions(worktree_path)

        remove_pr_description(worktree_path)

        unless system('git', 'push', '-u', 'origin', branch, chdir: worktree_path)
          committed.each do |c|
            @store.update_backlog_status(c[:backlog_item], BacklogStatus::Failed,
                                         failure_reason: FailureReason::PushError)
          end
          Log.error "push failed for #{branch}"
          return
        end

        pr_number = create_gh_pr(branch, title, body, worktree_path)

        committed.each do |c|
          @store.update_backlog_status(c[:backlog_item], BacklogStatus::PrOpen,
                                       pr_number: pr_number, branch: branch)
        end
        Log.info "PR ##{pr_number} created (#{committed.size} items)"

        last = committed.last
        Runner.analyze_run(last[:backlog_item].skill, item: last[:backlog_item].item,
                           log_path: last[:result].log_path, outcome: :success)
      end

      def combine_batch_descriptions(worktree_path)
        desc_dir = File.join(worktree_path, 'tmp', 'batch-descriptions')
        files = Dir.glob(File.join(desc_dir, '*.md')).sort

        if files.size == 1
          return parse_pr_description(File.read(files.first))
        end

        titles = []
        bodies = []
        files.each do |f|
          t, b = parse_pr_description(File.read(f))
          titles << t if t
          bodies << b if b && !b.empty?
        end

        [titles.first, bodies.join("\n\n---\n\n")]
      end

      def remove_pr_description(worktree_path)
        if system('git', 'ls-files', '--error-unmatch', 'pr-description.md', chdir: worktree_path, err: File::NULL)
          system('git', 'rm', '-f', 'pr-description.md', chdir: worktree_path)
          system('git', 'commit', '--no-gpg-sign', '-m', 'chore: remove pr-description.md', chdir: worktree_path)
        end
      end

      def create_gh_pr(branch, title, body, worktree_path)
        pr_args = ['gh', 'pr', 'create', '--head', branch, '--body', body]
        if title
          pr_args.push('--title', title)
        else
          pr_args.push('--fill')
        end
        pr_url, = Open3.capture2(*pr_args, chdir: worktree_path)
        pr_url.strip.split('/').last.to_i
      end

      def apply_patch(skill_name, patch_text)
        patterns_path = File.join(nightshift_dir, '.claude', 'skills', skill_name, 'patterns.md')

        content = if File.exist?(patterns_path)
                    File.read(patterns_path)
                  else
                    "# Patterns #{skill_name}\n"
                  end

        unless content.include?('## Auto-discovered pitfalls')
          content += "\n\n## Auto-discovered pitfalls\n\n<!-- Managed by autolearn. Review via kaizen synth. -->\n"
        end

        pitfall_count = content.scan(/^### AL-\d+/).size
        if pitfall_count >= 5
          Log.warn '🛑 5 auto-pitfalls cap reached — needs kaizen synth'
          return
        end

        pitfall_id = "AL-#{pitfall_count + 1}"
        timestamp = Time.now.strftime('%Y-%m-%d %H:%M')
        content += "\n### #{pitfall_id} (#{timestamp})\n\n#{patch_text.strip}\n"

        File.write(patterns_path, content)

        relative_path = patterns_path.sub("#{nightshift_dir}/", '')
        unless system('git', '-C', nightshift_dir, 'add', relative_path)
          Log.warn '⚠️ git add failed — patch written but not committed'
          return nil
        end

        unless system('git', '-C', nightshift_dir, 'commit', '--no-gpg-sign',
                      '-m', "autolearn(#{skill_name}): add #{pitfall_id}")
          Log.warn '⚠️ git commit failed'
          return nil
        end

        sha, = Open3.capture2('git', '-C', nightshift_dir, 'rev-parse', 'HEAD')
        Log.info "📝 appended #{pitfall_id} to patterns.md (#{sha.strip[0, 7]})"
        sha.strip
      end

      # Parse pr-description.md: extract frontmatter title and body
      def parse_pr_description(raw)
        if raw.start_with?("---\n")
          parts = raw.split("---\n", 3)
          if parts.length >= 3
            frontmatter = parts[1]
            body = parts[2].strip
            title_match = frontmatter.match(/^title:\s*"?(.+?)"?\s*$/m)
            title = title_match[1] if title_match
            return [title, body]
          end
        end
        [nil, raw]
      end

      private

      def write_pid_file(worktree_path)
        pid_path = File.join(worktree_path, 'tmp', 'nightshift.pid')
        FileUtils.mkdir_p(File.dirname(pid_path))
        File.write(pid_path, Process.pid.to_s)
      end

      def remove_pid_file(worktree_path)
        FileUtils.rm_f(File.join(worktree_path, 'tmp', 'nightshift.pid'))
      end

      def nightshift_dir
        File.expand_path('../../..', __dir__)
      end
    end
  end
end
