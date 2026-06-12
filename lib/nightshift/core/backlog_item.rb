# frozen_string_literal: true
# typed: true

module Nightshift
  module Core
    #
    # BacklogItem — Single work item in the skill backlog
    #
    # Tracks a file to be processed by a skill through its lifecycle:
    # pending → running → pr_open → done (or failed/skipped).
    # Carries retry metadata, scheduling, and optional context for the LLM.
    #
    class BacklogItem < T::Struct
      extend T::Sig

      const :id, Integer
      const :skill, String
      const :item, String
      const :status, BacklogStatus
      const :branch, T.nilable(String), default: nil
      const :pr_number, T.nilable(Integer), default: nil
      const :failure_reason, T.nilable(String), default: nil
      const :priority, Integer, default: 0
      const :retry_count, Integer, default: 0
      const :last_verdict, T.nilable(String), default: nil
      const :retry_after, T.nilable(Integer), default: nil
      const :context, T.nilable(String), default: nil
      const :created_at, Integer
      const :updated_at, Integer

      # Build from a Sequel row hash
      sig { params(row: T::Hash[Symbol, T.untyped]).returns(BacklogItem) }
      def self.from_row(row)
        new(
          id: row[:id], skill: row[:skill], item: row[:item],
          status: BacklogStatus.deserialize(row[:status]), branch: row[:branch],
          pr_number: row[:pr_number], failure_reason: row[:failure_reason],
          priority: row[:priority] || 0, retry_count: row[:retry_count] || 0,
          last_verdict: row[:last_verdict], retry_after: row[:retry_after],
          context: row[:context],
          created_at: row[:created_at], updated_at: row[:updated_at]
        )
      end
    end
  end
end
