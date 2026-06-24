# frozen_string_literal: true
# typed: true

module Nightshift
  # Why a backlog item failed: claude_error, no_diff, push_error, worktree_error, etc.
  class FailureReason < T::Enum
    enums do
      ClaudeError         = new('claude_error')
      NoDiff              = new('no_diff')
      RateLimited         = new('rate_limited')
      NoPrDescription     = new('no_pr_description')
      PushError           = new('push_error')
      FileNotFound        = new('file_not_found')
      WorktreeError       = new('worktree_error')
      ZombieExhausted     = new('zombie_exhausted')
      ResolvedUpstream    = new('resolved_upstream')
      ManualClose         = new('manual_close')
      AutolearnExhausted  = new('autolearn_exhausted')
    end
  end
end
