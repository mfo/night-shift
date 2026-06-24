# frozen_string_literal: true

module Nightshift
  module Core
    class LLMBackend < T::Struct
      const :name, String
      const :harness, String
      const :concurrency, Integer, default: 1
    end
  end
end
