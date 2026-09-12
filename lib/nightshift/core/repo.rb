# frozen_string_literal: true

module Nightshift
  module Core
    # Un repo de travail : la ou un skill cree ses worktrees et ouvre ses PRs.
    #
    # Le harness n'en connaissait qu'un, celui passe a `--repo`, qui cumulait
    # trois roles — porter la config, porter la base, et servir de source aux
    # worktrees. `Repo` separe le troisieme des deux premiers.
    class Repo < T::Struct
      extend T::Sig

      const :name, String
      const :path, String

      # `owner/name` GitHub. Declare plutot que derive par `gh repo view`, qui
      # serait un appel reseau par repo a chaque tick.
      const :slug, T.nilable(String), default: nil

      # La branche de base des worktrees et des diffs. Etait `main` en dur.
      const :main_branch, String, default: 'main'

      # Exactement l'un des deux. `allow` liste ce qui compte comme vrai
      # changement, `deny` ce qui n'en est pas. Un repo applicatif veut une
      # allowlist — on ignore volontiers un README modifie seul. Un repo de
      # documentation veut une denylist : il grossit par nature, et toute page
      # ajoutee a la racine tomberait hors d'une allowlist sans que personne
      # pense a mettre le YAML a jour.
      const :content_allow, T.nilable(T::Array[String]), default: nil
      const :content_deny, T.nilable(T::Array[String]), default: nil

      # Ce que `Worktree.setup` embarque dans un worktree frais. `nil` = tout.
      const :worktree_skills, T.nilable(T::Array[String]), default: nil
      const :worktree_agents, T.nilable(T::Array[String]), default: nil

      # Ce chemin, tel qu'il sort de `git diff --name-only`, compte-t-il comme
      # un changement reel ? C'est un classificateur de diff, pas une borne
      # d'ecriture : il ne restreint rien, il requalifie.
      sig { params(path_in_repo: String).returns(T::Boolean) }
      def content?(path_in_repo)
        allow = content_allow
        return allow.any? { |p| under?(path_in_repo, p) } if allow

        (content_deny || []).none? { |p| under?(path_in_repo, p) }
      end

      private

      # Egalite exacte pour un fichier a la racine (`SUMMARY.md`), prefixe
      # suivi du separateur pour un repertoire — sans quoi `app` matcherait
      # `apparence.rb`, et `^(app|lib)/` ferait disparaitre `SUMMARY.md`.
      sig { params(path_in_repo: String, prefix: String).returns(T::Boolean) }
      def under?(path_in_repo, prefix)
        path_in_repo == prefix || path_in_repo.start_with?("#{prefix}/")
      end
    end
  end
end
