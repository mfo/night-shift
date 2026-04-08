# Kaizen -- Bugfix referentiel nil guard (Sentry #7305936356)
Date: 2026-03-26 | Skill: bugfix | Score: 7/10

## Ce qui s'est passé
- Bug Sentry: `NoMethodError: undefined method 'id' for nil` dans `ReferentielComponent`
- Mode 2 (rapport Sentry existant) — investigation rapide, root cause identifiée en quelques minutes
- Fix: guard `referentiel.blank?` dans le template + message d'erreur DSFR + spec
- PR ouverte: https://github.com/demarche-numerique/demarche.numerique.gouv.fr/pull/12878

## Ce qui s'est bien passé
- Investigation rapide grâce à la stack trace Sentry claire
- Bonne collaboration : l'utilisateur a challengé sur la root cause (callback `clean_referentiel`), ce qui a permis de confirmer que le bug était pré-existant (7 mois)
- Screenshots Playwright + gist ont bien fonctionné pour documenter la PR
- Le fix est minimal et bien intégré dans les patterns DSFR existants (`InputStatusMessageComponent`)

## Ce qui s'est mal passé
- Trop de temps perdu sur le setup Playwright (trusted_device cookie, mauvais repo Rails.root)
- Premier essai de spec avec un mock `FormBuilder` incomplet — aurait dû chercher les patterns existants d'abord
- Confusion sur "marge autour du screenshot" : j'ai ajouté du padding CSS dans la page au lieu de capturer un élément parent plus large
- Le skill bugfix propose un plan de commits obligatoire, l'utilisateur a dit "pas besoin" — le skill est trop rigide sur ce point

## Ce qu'on a appris
- Le pattern pour screenshoter un composant avec contexte : cibler l'élément parent (ex: le `group` du formulaire) plutôt qu'ajouter du CSS
- Les specs de composants editable_champ utilisent `ActionView::Helpers::FormBuilder.new(...)` avec un vrai view_context, pas un simple mock
- `belongs_to :referentiel, optional: true` + `delegate :exact_match?, allow_nil: true` cache le nil jusqu'au moment où on appelle `.id`

## Permissions bloquantes (demandées interactivement)

| Permission | Pourquoi |
|---|---|
| `Bash(bundle exec rspec:*)` | Exécution des specs |
| `mcp__playwright__*` | Navigation, screenshots |

## Actions
- [ ] Améliorer le skill bugfix : rendre le plan de commits optionnel (proposer mais ne pas bloquer si l'utilisateur refuse)
- [ ] Ajouter au skill screenshot-gist : documenter l'astuce "capturer un parent plus large" plutôt que d'ajouter du padding CSS
