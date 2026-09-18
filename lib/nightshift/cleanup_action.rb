# frozen_string_literal: true
# typed: true

module Nightshift
  # What the doctor would do to reclaim a work item.
  class CleanupAction < T::Enum
    enums do
      CloseWorktree = new('close_worktree')  # worktree remove + drop DB + delete branch
      PruneAdmin    = new('prune_admin')     # git worktree prune (dossier disparu)
      RemoveDir     = new('remove_dir')      # rm -rf d'un dossier fantôme
      DropDatabase  = new('drop_database')   # dropdb
      DeleteBranch  = new('delete_branch')   # git branch -d
    end
  end
end
