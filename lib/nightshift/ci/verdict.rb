# typed: true

module Nightshift
  module CI
    class Verdict < T::Struct
      const :verdict, String
      const :root_cause, String, default: ""
      const :fixable_by_skill_update, T::Boolean, default: false
      const :suggested_patch, T.nilable(String), default: nil
      const :confidence, Float, default: 0.0
    end
  end
end
