# Kaizen -- rescue_from MissingTemplate pour formats non supportés
Date: 2026-03-26 | Skill: bugfix | Score: 8/10

## Ce qui s'est passé
- Bug Sentry: `GET /graphql.zip` → `ActionView::MissingTemplate` → 500 en prod
- Investigation rapide : le problème est global, pas juste GraphQL (toutes les actions avec render implicite)
- Discussion sur l'approche : `respond_to` par contrôleur vs route constraints vs `rescue_from` global
- Choix du pattern standard Rails : `rescue_from ActionView::MissingTemplate` avec re-raise sélectif (HTML/turbo_stream = vrai bug, autre format = 406)
- Implémentation TDD dans `ApplicationController::ErrorHandling`, 4 tests verts
- PR #12879 créée

## Ce qui s'est bien passé
- La discussion itérative sur les alternatives a permis de converger vers la meilleure solution
- Le pattern industrie (rescue_from avec re-raise sélectif) est élégant et couvre tous les cas
- Investigation agent en parallèle a bien identifié l'étendue du problème (dizaines de routes vulnérables)
- Fix global = 0 maintenance future vs `respond_to` dans chaque contrôleur

## Ce qui s'est mal passé
- Premier test rouge utilisait `render html:` qui ne passe pas par le système de templates → test faussement vert
- Deuxième tentative avec `render template: 'root/administration'` → template existait en HTML → pas de MissingTemplate
- Troisième tentative avec `render template: 'nonexistent/template'` → OK
- Le push initial n'a pas configuré le tracking remote correctement (rtk proxy)
- Propositions initiales (respond_to, route constraints) sans chercher le standard industrie → l'utilisateur a dû demander "c'est quoi l'approche de l'industrie ?" pour qu'on arrive à la bonne solution

## Ce qu'on a appris
- ...

## Permissions bloquantes (demandées interactivement)

| Permission | Pourquoi |
|---|---|
| `Bash(git push)` | Push de la branche vers le remote |
| `Bash(gh pr create)` | Création de la PR |
| `Edit(error_handling.rb)` | Premier edit refusé (format trop verbeux) |

## Actions
- [ ] Documenter dans le skill bugfix : quand on teste un `rescue_from` sur MissingTemplate, l'action du contrôleur anonyme doit utiliser `render template: 'nonexistent/template'` (pas `render html:` ni un template existant)
- [ ] Ajouter dans le skill bugfix : lors de la phase Solutions, toujours rechercher le standard de l'industrie / pattern communautaire avant de proposer des solutions ad-hoc. Ne pas attendre que l'utilisateur demande.
