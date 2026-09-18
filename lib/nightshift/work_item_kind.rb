# frozen_string_literal: true
# typed: true

module Nightshift
  # What a line of the inventory actually is.
  #
  # One work item = one thing that exists somewhere (a worktree, a PR, a
  # directory, a database, a branch). The kind says where it lives, not what
  # should happen to it — that is CleanupAction's job.
  class WorkItemKind < T::Enum
    enums do
      Pr          = new('pr')            # an open PR with no local worktree
      Worktree    = new('worktree')      # a registered git worktree
      GhostDir    = new('ghost_dir')     # a directory left behind by a removed worktree
      OrphanDb    = new('orphan_db')     # a tps_test_* database no worktree claims
      StaleBranch = new('stale_branch')  # a local branch merged into base, no worktree
    end
  end
end
