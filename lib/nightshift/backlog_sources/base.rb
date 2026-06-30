# frozen_string_literal: true

module Nightshift
  module BacklogSources
    class Base
      extend T::Sig

      HIGHEST = 5
      HIGH    = 4
      MEDIUM  = 3
      LOW     = 2
      LOWEST  = 1
      LATER   = 0

      VIEW_PRIORITY_MAP = T.let([
        [%r{shared/}, HIGHEST],
        [%r{(^|/)root/|static_pages/|faq/|contact/|stats/|france_connect/|pro_connect/|prefill_|recherche/}, HIGHEST],
        [%r{(^|/)users/|dossier_mailer/|user_mailer/|invite_mailer/|devise|editable_champ/|phishing_alert|quotient_familial}, HIGH],
        [%r{instructeurs/|experts/|instructeur_mailer/|expert_mailer/|avis_mailer/|notification_mailer/}, MEDIUM],
        [%r{administrateurs/|procedure/|types_de_champ_editor/|groupe_instructeur_mailer/|administration_mailer/|conditions/|referentiels/}, LOW],
        [%r{super_admins/|gestionnaires/|groupe_gestionnaire|manager/|administrate/|layouts/|release_note}, LATER]
      ].freeze, T::Array[[Regexp, Integer]])

      attr_reader :repo_path

      sig { params(repo_path: String).void }
      def initialize(repo_path)
        @repo_path = repo_path
      end

      sig { returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def items
        raw = scan
        raw = raw.select { |item| relevant?(item[:item]) }
        raw.map { |item| item.merge(priority: prioritize(item)) }
      end

      sig { overridable.returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def scan
        raise NotImplementedError
      end

      sig { overridable.params(item_path: String).returns(T::Boolean) }
      def relevant?(item_path)
        true
      end

      sig { overridable.params(item: T::Hash[Symbol, T.untyped]).returns(Integer) }
      def prioritize(item)
        0
      end

      private

      sig { params(pattern: String).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def glob(pattern)
        Dir.glob(File.join(repo_path, pattern)).map do |f|
          { item: f.sub("#{repo_path}/", '') }
        end
      end

      sig { params(path: String).returns(Integer) }
      def prioritize_by_view_path(path)
        VIEW_PRIORITY_MAP.each { |pattern, prio| return prio if path.match?(pattern) }
        MEDIUM
      end
    end
  end
end
