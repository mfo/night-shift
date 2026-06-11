# frozen_string_literal: true
# typed: false

require 'open3'

module Nightshift
  module Skills
    class Pipeline
      extend T::Sig

      sig { params(store: Core::Store).void }
      def initialize(store:)
        @store = store
      end

      sig do
        params(
          skill: String,
          item_path: String,
          worktree_path: String,
          context: T.nilable(String)
        ).void
      end
      def execute(skill, item_path, worktree_path:, context: nil)
        result = Runner.run(skill, item: item_path, worktree_path: worktree_path, context: context)

        branch, = Open3.capture2('git', 'rev-parse', '--abbrev-ref', 'HEAD',
                                 chdir: worktree_path)
        branch = branch.strip
        backlog_item = @store.backlog_by_branch(branch)

        unless backlog_item
          Log.warn "no backlog item for branch #{branch}"
          return
        end

        unless result.success
          handle_failure(skill, item_path, worktree_path, backlog_item, result)
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
          handle_failure(skill, item_path, worktree_path, backlog_item, no_desc_result)
          return
        end

        # Read pr-description.md BEFORE removing it from git
        raw = File.read(desc_path)
        title, body = parse_pr_description(raw)

        # Remove pr-description.md from git before push (it's a pipeline artifact, not source code)
        if system('git', 'ls-files', '--error-unmatch', 'pr-description.md', chdir: worktree_path, err: File::NULL)
          system('git', 'rm', '-f', 'pr-description.md', chdir: worktree_path)
          system('git', 'commit', '--no-gpg-sign', '-m', 'chore: remove pr-description.md', chdir: worktree_path)
        end

        # Push
        unless system('git', 'push', '-u', 'origin', branch, chdir: worktree_path)
          @store.update_backlog_status(backlog_item.id, BacklogStatus::Failed,
                                       failure_reason: FailureReason::PushError.serialize)
          Log.error "push failed for #{branch}"
          return
        end

        # Create PR
        pr_args = ['gh', 'pr', 'create', '--head', branch, '--body', body]
        if title
          pr_args.push('--title', title)
        else
          pr_args.push('--fill')
        end
        pr_url, = Open3.capture2(*pr_args, chdir: worktree_path)
        pr_number = pr_url.strip.split('/').last.to_i

        @store.update_backlog_status(backlog_item.id, BacklogStatus::PrOpen,
                                     pr_number: pr_number, branch: branch)
        Log.info "PR ##{pr_number} created"

        record_cycle(backlog_item, verdict: VerdictName::Success, outcome: 'improved',
                                   log_path: result.log_path, turns: result.turns_used)
      end

      sig do
        params(
          skill: String,
          item_path: String,
          worktree_path: String,
          backlog_item: Core::BacklogItem,
          result: RunnerResult
        ).void
      end
      def handle_failure(skill, item_path, worktree_path, backlog_item, result)
        failure_reason = result.failure_reason
        retry_count = backlog_item.retry_count.to_i

        # Rate limit: skip judge (would also be rate-limited), backoff 30min
        if failure_reason == FailureReason::RateLimited.serialize
          Log.warn 'rate limited — backoff 30min'
          record_cycle(backlog_item, verdict: VerdictName::RateLimited,
                                     root_cause: 'rate_limited', log_path: result.log_path,
                                     turns: result.turns_used)
          branch, = Open3.capture2('git', 'rev-parse', '--abbrev-ref', 'HEAD',
                                   chdir: worktree_path)
          Integrations::Worktree.cleanup(branch.strip)
          @store.update_backlog_status(backlog_item.id, BacklogStatus::Pending,
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
        record_cycle(backlog_item, verdict: verdict.verdict,
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
          # Apply patch if skill_defect with good confidence
          if verdict.verdict == VerdictName::SkillDefect && verdict.suggested_patch && verdict.confidence >= 0.5
            sha = apply_patch(skill, verdict.suggested_patch)
            if sha
              last_cycle_id = @store.db[:autolearn_cycles]
                                    .where(backlog_item_id: backlog_item.id)
                                    .order(Sequel.desc(:id)).get(:id)
              if last_cycle_id
                @store.db[:autolearn_cycles]
                      .where(id: last_cycle_id)
                      .update(skill_patch_sha: sha)
              end
            end
          end

          # Clean up worktree before reset — the reconciler will create a fresh one
          branch, = Open3.capture2('git', 'rev-parse', '--abbrev-ref', 'HEAD',
                                   chdir: worktree_path)
          Integrations::Worktree.cleanup(branch.strip)

          # Reset to pending — the reconciler will re-launch on next cycle
          @store.update_backlog_status(backlog_item.id, BacklogStatus::Pending,
                                       branch: nil, failure_reason: nil,
                                       last_verdict: verdict.verdict.serialize)
          @store.db[:backlog_items].where(id: backlog_item.id)
                .update(retry_count: Sequel.expr(:retry_count) + 1)
          Log.info "🔄 reset to pending (retry #{retry_count + 1}/#{CI::Judge::MAX_RETRIES}) — reconciler will re-launch"
        else
          reason = retry_count >= CI::Judge::MAX_RETRIES ? FailureReason::AutolearnExhausted.serialize : verdict.verdict.serialize

          # Clean up worktree before marking as skipped
          branch, = Open3.capture2('git', 'rev-parse', '--abbrev-ref', 'HEAD',
                                   chdir: worktree_path)
          Integrations::Worktree.cleanup(branch.strip)

          @store.update_backlog_status(backlog_item.id, BacklogStatus::Skipped,
                                       failure_reason: reason, branch: nil,
                                       last_verdict: verdict.verdict.serialize)
          Log.info "⏭ skipped (#{reason})"
        end
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

      def record_cycle(backlog_item, verdict:, root_cause: nil,
                       suggested_patch: nil, log_path: nil, turns: nil,
                       outcome: nil, skill_patch_sha: nil, confidence: nil)
        retry_count = backlog_item.retry_count.to_i
        @store.db[:autolearn_cycles].insert(
          backlog_item_id: backlog_item.id,
          attempt: retry_count + 1,
          verdict: verdict.serialize,
          root_cause: root_cause,
          suggested_patch: suggested_patch,
          confidence: confidence,
          skill_patch_sha: skill_patch_sha,
          outcome: outcome,
          log_path: log_path,
          turns_used: turns,
          created_at: Time.now.to_i
        )
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

      def nightshift_dir
        File.expand_path('../../..', __dir__)
      end
    end
  end
end
