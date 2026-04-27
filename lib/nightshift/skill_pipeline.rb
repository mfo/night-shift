require "open3"

module Nightshift
  class SkillPipeline
    def initialize(store:)
      @store = store
    end

    def execute(skill, item_path, worktree_path:)
      result = SkillRunner.run(skill, item: item_path, worktree_path: worktree_path)

      branch, = Open3.capture2("git", "rev-parse", "--abbrev-ref", "HEAD",
                               chdir: worktree_path)
      branch = branch.strip
      backlog_item = @store.backlog_by_branch(branch)

      unless backlog_item
        puts "nightshift: no backlog item for branch #{branch}"
        return
      end

      unless result[:success]
        handle_failure(skill, item_path, worktree_path, backlog_item, result)
        return
      end

      # Check pr-description.md
      desc_path = File.join(worktree_path, "pr-description.md")
      unless File.exist?(desc_path)
        handle_failure(skill, item_path, worktree_path, backlog_item,
                       result.merge(failure_reason: "no_pr_description"))
        return
      end

      # Push
      unless system("git", "push", "-u", "origin", branch, chdir: worktree_path)
        @store.update_backlog_status(backlog_item[:id], "failed",
                                     failure_reason: "push_error")
        puts "nightshift: push failed"
        return
      end

      # Create PR
      body = File.read(desc_path)
      pr_url, = Open3.capture2("gh", "pr", "create", "--head", branch,
                               "--fill", "--body", body, chdir: worktree_path)
      pr_number = pr_url.strip.split("/").last.to_i

      @store.update_backlog_status(backlog_item[:id], "pr_open",
                                   pr_number: pr_number, branch: branch)
      puts "nightshift: PR ##{pr_number} created"

      record_cycle(backlog_item, verdict: "success", outcome: "improved",
                   log_path: result[:log_path], turns: result[:turns_used])
    end

    def handle_failure(skill, item_path, worktree_path, backlog_item, result)
      failure_reason = result[:failure_reason]
      retry_count = backlog_item[:retry_count].to_i

      puts "nightshift: skill failed (#{failure_reason}) — invoking judge"

      # Judge: analyze the failure
      verdict = Judge.evaluate(skill, item: item_path,
                               log_path: result[:log_path],
                               failure_reason: failure_reason)

      puts "  ┌─ verdict: #{verdict[:verdict]} (confidence: #{verdict[:confidence]})"
      puts "  │  cause: #{verdict[:root_cause]}"
      puts "  └─ patch: #{verdict[:suggested_patch] ? 'yes' : 'none'}"

      # Record the cycle
      record_cycle(backlog_item, verdict: verdict[:verdict],
                   root_cause: verdict[:root_cause],
                   suggested_patch: verdict[:suggested_patch],
                   log_path: result[:log_path], turns: result[:turns_used])

      # Store infra suggestion if infra_error
      if verdict[:verdict] == "infra_error" && verdict[:root_cause]
        @store.add_infra_suggestion(skill: skill, description: verdict[:root_cause],
                                    source: "judge", backlog_item_id: backlog_item[:id])
        puts "  💡 infra suggestion enregistree"
      end

      # Decide: retry or stop
      if Judge.retryable?(verdict, retry_count)
        # Apply patch if skill_defect with good confidence
        if verdict[:verdict] == "skill_defect" && verdict[:suggested_patch] && verdict[:confidence] >= 0.5
          apply_patch(skill, verdict[:suggested_patch])
        end

        # Clean up worktree before reset — the reconciler will create a fresh one
        branch, = Open3.capture2("git", "rev-parse", "--abbrev-ref", "HEAD",
                                 chdir: worktree_path)
        Worktree.cleanup(branch.strip)

        # Reset to pending — the reconciler will re-launch on next cycle
        @store.update_backlog_status(backlog_item[:id], "pending",
                                     branch: nil, failure_reason: nil,
                                     last_verdict: verdict[:verdict])
        @store.db[:backlog_items].where(id: backlog_item[:id])
          .update(retry_count: Sequel.expr(:retry_count) + 1)
        puts "  🔄 reset to pending (retry #{retry_count + 1}/#{Judge::MAX_RETRIES}) — reconciler will re-launch"
      else
        reason = retry_count >= Judge::MAX_RETRIES ? "autolearn_exhausted" : verdict[:verdict]
        @store.update_backlog_status(backlog_item[:id], "skipped",
                                     failure_reason: reason,
                                     last_verdict: verdict[:verdict])
        puts "  ⏭ skipped (#{reason})"
      end
    end

    def apply_patch(skill_name, patch_text)
      nightshift_dir = File.expand_path("../..", __dir__)
      patterns_path = File.join(nightshift_dir, ".claude", "skills", skill_name, "patterns.md")

      unless File.exist?(patterns_path)
        puts "  ⚠️ patterns.md not found for #{skill_name}"
        return
      end

      content = File.read(patterns_path)
      unless content.include?("## Auto-discovered pitfalls")
        content += "\n\n## Auto-discovered pitfalls\n\n<!-- Managed by autolearn. Review via kaizen synth. -->\n"
      end

      pitfall_count = content.scan(/^### AL-\d+/).size
      if pitfall_count >= 5
        puts "  🛑 5 auto-pitfalls cap reached — needs kaizen synth"
        return
      end

      pitfall_id = "AL-#{pitfall_count + 1}"
      timestamp = Time.now.strftime("%Y-%m-%d %H:%M")
      content += "\n### #{pitfall_id} (#{timestamp})\n\n#{patch_text.strip}\n"

      File.write(patterns_path, content)
      system("git", "-C", nightshift_dir, "add", patterns_path.sub("#{nightshift_dir}/", ""))
      system("git", "-C", nightshift_dir, "commit", "--no-gpg-sign",
             "-m", "autolearn(#{skill_name}): add #{pitfall_id}")
      puts "  📝 appended #{pitfall_id} to patterns.md"
    end

    def record_cycle(backlog_item, verdict:, root_cause: nil,
                     suggested_patch: nil, log_path: nil, turns: nil,
                     outcome: nil, skill_patch_sha: nil)
      retry_count = backlog_item[:retry_count].to_i
      @store.db[:autolearn_cycles].insert(
        backlog_item_id: backlog_item[:id],
        attempt: retry_count + 1,
        verdict: verdict.to_s,
        root_cause: root_cause,
        suggested_patch: suggested_patch,
        skill_patch_sha: skill_patch_sha,
        outcome: outcome,
        log_path: log_path,
        turns_used: turns,
        created_at: Time.now.to_i
      )
    end
  end
end
