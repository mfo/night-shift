# frozen_string_literal: true

module Nightshift
  module BacklogSources
    extend T::Sig

    REGISTRY = T.let({
      'haml-migration'    => 'HamlMigration',
      'i18n-hardcoded'    => 'I18nHardcoded',
      'test-optimization' => 'TestOptimization',
      'n1-query-fix'      => 'N1QueryFix',
      'flaky-test-fix'    => 'FlakyTestFix'
    }.freeze, T::Hash[String, String])

    sig { params(skill_name: String, repo_path: String).returns(T.nilable(BacklogSources::Base)) }
    def self.for(skill_name, repo_path)
      class_name = REGISTRY[skill_name]
      return nil unless class_name

      const_get(class_name).new(repo_path)
    end
  end
end
