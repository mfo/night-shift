# frozen_string_literal: true
# typed: true

module Nightshift
  module Core
    class AutolearnCycle < T::Struct
      extend T::Sig

      const :id, Integer
      const :backlog_item_id, Integer
      const :attempt, Integer
      const :verdict, T.nilable(String), default: nil
      const :root_cause, T.nilable(String), default: nil
      const :suggested_patch, T.nilable(String), default: nil
      const :confidence, T.nilable(Float), default: nil
      const :skill_patch_sha, T.nilable(String), default: nil
      const :outcome, T.nilable(String), default: nil
      const :log_path, T.nilable(String), default: nil
      const :turns_used, T.nilable(Integer), default: nil
      const :created_at, Integer

      sig { params(row: T::Hash[Symbol, T.untyped]).returns(AutolearnCycle) }
      def self.from_row(row)
        new(
          id: row[:id], backlog_item_id: row[:backlog_item_id],
          attempt: row[:attempt], verdict: row[:verdict],
          root_cause: row[:root_cause], suggested_patch: row[:suggested_patch],
          confidence: row[:confidence], skill_patch_sha: row[:skill_patch_sha],
          outcome: row[:outcome], log_path: row[:log_path],
          turns_used: row[:turns_used], created_at: row[:created_at]
        )
      end
    end
  end
end
