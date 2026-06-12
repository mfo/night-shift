# frozen_string_literal: true
# typed: true

module Nightshift
  module Skills
    #
    # RunnerResult — Output of a skill runner invocation
    #
    # Carries the success flag, optional failure reason, log path,
    # turn count, and number of files changed. Consumed by Pipeline
    # to decide the next step (PR creation or judge evaluation).
    #
    class RunnerResult < T::Struct
      const :success, T::Boolean
      const :failure_reason, T.nilable(String), default: nil
      const :log_path, String
      const :turns_used, T.nilable(Integer), default: nil
      const :files_changed, Integer, default: 0
    end
  end
end
