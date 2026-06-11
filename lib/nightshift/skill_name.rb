# frozen_string_literal: true
# typed: true

module Nightshift
  class SkillName < T::Enum
    enums do
      HamlMigration    = new('haml-migration')
      TestOptimization = new('test-optimization')
      I18nHardcoded    = new('i18n-hardcoded')
      N1QueryFix       = new('n1-query-fix')
      Reprioritize     = new('reprioritize')
    end
  end
end
