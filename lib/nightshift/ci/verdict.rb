# frozen_string_literal: true
# typed: true

module Nightshift
  module CI
    #
    # Verdict — Structured output from the Judge
    #
    # Holds the verdict name, root cause analysis, whether the skill
    # prompt can be patched, an optional suggested patch for patterns.md,
    # and the judge's confidence score (0.0–1.0).
    #
    class Verdict < T::Struct
      const :verdict, VerdictName
      const :root_cause, String, default: ''
      const :fixable_by_skill_update, T::Boolean, default: false
      const :suggested_patch, T.nilable(String), default: nil
      const :confidence, Float, default: 0.0
    end
  end
end
