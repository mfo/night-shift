# frozen_string_literal: true
# typed: true

module Nightshift
  module Skills
    class RunnerResult < T::Struct
      const :success, T::Boolean
      const :failure_reason, T.nilable(String), default: nil
      const :log_path, String
      const :turns_used, T.nilable(Integer), default: nil
      const :files_changed, Integer, default: 0
    end
  end
end
