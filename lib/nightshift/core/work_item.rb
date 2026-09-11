# frozen_string_literal: true
# typed: true

module Nightshift
  module Core
    #
    # WorkItem — one line of the global inventory
    #
    # Everything in flight or left behind is reduced to this shape, whatever it
    # is: a worktree, a PR without a worktree, a ghost directory, an orphan
    # database, a stale branch. `cleanup` is set when the doctor has an action
    # for it; `safe_to_clean?` is what stands between that action and a loss of
    # uncommitted work.
    #
    class WorkItem < T::Struct
      extend T::Sig

      const :kind, WorkItemKind
      const :label, String
      const :origin, WorkItemOrigin, default: WorkItemOrigin::Unknown
      const :repo, T.nilable(String), default: nil
      const :path, T.nilable(String), default: nil
      const :branch, T.nilable(String), default: nil
      const :pr_number, T.nilable(Integer), default: nil
      const :pr_state, T.nilable(PRState), default: nil
      const :github_state, T.nilable(String), default: nil
      prop :size_bytes, Integer, default: 0
      prop :dirty, T::Boolean, default: false
      prop :unpushed, T::Boolean, default: false
      # git could not be questioned at all (dangling .git, missing admin entry)
      prop :unknown_state, T::Boolean, default: false
      const :locked, T::Boolean, default: false
      const :detached, T::Boolean, default: false
      const :missing_dir, T::Boolean, default: false
      const :cleanup, T.nilable(CleanupAction), default: nil
      const :reason, T.nilable(String), default: nil

      sig { returns(T::Boolean) }
      def worktree? = !path.nil?

      sig { returns(T::Boolean) }
      def open_pr? = github_state == 'OPEN'

      # The single gate before anything destructive. A locked worktree belongs
      # to someone else; uncommitted or unpushed work exists nowhere but here;
      # an unverifiable directory is not something we get to guess about.
      sig { returns(T::Boolean) }
      def safe_to_clean? = !dirty && !unpushed && !locked && !unknown_state

      sig { returns(T::Array[String]) }
      def blockers
        b = []
        b << 'modifs non commitées' if dirty
        b << 'commits non poussés' if unpushed
        b << 'worktree verrouillé' if locked
        b << 'état git non vérifiable' if unknown_state
        b
      end

      sig { returns(String) }
      def human_size = size_bytes.zero? ? '' : Nightshift.human_size(size_bytes)
    end
  end
end
