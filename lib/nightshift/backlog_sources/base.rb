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

      # --- Nature de la source ---
      #
      # Les cinq sources historiques sont *derivees* : elles reglobbent le repo
      # cible a chaque scan, et leur resultat est la verite complete du moment.
      # Une source *journal* lit un flux append-only exterieur, ou l'absence ne
      # signifie rien. Les trois predicats ci-dessous disent laquelle on est.
      # Ils restent separes plutot que fusionnes en un `journal?` : ils repondent
      # a trois questions distinctes, et rien ne prouve encore qu'ils ne
      # divergeront pas.

      # Avant de lancer un skill, le Reconciler verifie l'existence de l'item par
      # `git cat-file -e HEAD:<item>`. Un tag de release n'est pas un blob : la
      # garde le classerait Skipped(FileNotFound) sans qu'il ait tourne.
      sig { overridable.returns(T::Boolean) }
      def file_backed?
        true
      end

      # `reconcile_backlog` passe en Skipped(ResolvedUpstream) tout item pending
      # absent du scan. C'est juste pour un glob — le fichier a disparu, l'item
      # n'a plus d'objet. Ca ne l'est pas pour un journal : une entree sortie de
      # la fenetre de fetch n'est pas resolue, elle est hors de portee, et la
      # pruner la perdrait definitivement.
      sig { overridable.returns(T::Boolean) }
      def prunable?
        true
      end

      # Le Reprioritizer rejoue les priorites a partir de donnees Skylight de
      # production, via un `claude -p` synchrone dans le tick du reconciler. Sur
      # un backlog de releases il n'a rien a apprendre — la priorite est calculee
      # a l'ingestion — et le cout serait paye pour rien.
      sig { overridable.returns(T::Boolean) }
      def reprioritizable?
        true
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
