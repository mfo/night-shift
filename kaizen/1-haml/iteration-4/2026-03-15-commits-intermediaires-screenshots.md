# Le LLM ne suit pas le plan de commit

**Date :** 2026-03-15
**Fichiers concernés :** `instructeur_mailer/send_notifications.html.haml`

## Ce qui s'est passé

Migration HAML → ERB. Le LLM a fait un seul commit final au lieu de commits intermédiaires avec les screenshots (HAML avant, ERB après).

## Problème racine

Le skill `haml-migration/SKILL.md` décrit les étapes de capture mais ne prescrit pas explicitement de committer les screenshots à chaque étape. L'étape 6 "Commit" est un bloc unique → le LLM condense tout.

## Ce qui a été appris

Le LLM suit les instructions littérales. Si le skill dit "capturer" mais ne dit pas "committer", il ne committera pas. Il faut être explicite sur chaque commit intermédiaire.

## Action

Modifier `SKILL.md` pour ajouter des commits explicites :
- Après étape 2 : `git add tmp/screenshots/haml/ && git commit -m "chore: screenshots HAML avant migration [BATCH]"`
- Après étape 5 : `git add tmp/screenshots/erb/ && git commit -m "chore: screenshots ERB après migration [BATCH]"`
- Étape 6 : commit final de migration (suppression HAML + ajout ERB)

**Cible :** `SKILL.md` étapes 2, 5, 6

## Permissions à ajouter au skill

Pendant la session, plusieurs permissions ont été demandées interactivement. Les ajouter aux autorisations du skill pour fluidifier l'exécution :

- `git rm` — suppression des fichiers HAML
- `git mv` — renommage des specs `.haml_spec.rb` → `.erb_spec.rb`
- `git commit` — commits intermédiaires + final
- `Bash: bun lint:herb` — linter ERB
- `Bash: bundle exec rspec` — tests
- `mcp__playwright__browser_navigate` — navigation pages
- `mcp__playwright__browser_run_code` — capture screenshots

**Cible :** configuration permissions du skill
