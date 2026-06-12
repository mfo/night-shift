# frozen_string_literal: true
# typed: true

module Nightshift
  # Judge verdict outcomes: skill_defect, item_hard, infra_error, context_limit, + sentinels
  class VerdictName < T::Enum
    enums do
      SkillDefect    = new('skill_defect')
      ItemHard       = new('item_hard')
      InfraError     = new('infra_error')
      ContextLimit   = new('context_limit')
      Success        = new('success')
      RateLimited    = new('rate_limited')
      LogMissing     = new('log_missing')
      JudgeError     = new('judge_error')
      ParseError     = new('parse_error')
      UnknownVerdict = new('unknown_verdict')
    end
  end
end
