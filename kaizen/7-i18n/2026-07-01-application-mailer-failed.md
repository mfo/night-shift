---
status: traité
date_synth: 2026-07-08
---

# Kaizen — i18n-hardcoded : application_mailer.rb (FAILED)

**Date** : 2026-07-01
**Skill** : i18n-hardcoded
**Item** : `app/mailers/application_mailer.rb`
**Reason** : `no_diff`
**Durée** : 157ms / 0 turns / 0 tokens

## Ce qui s'est passé

Le Runner a lancé `claude -p` avec `/i18n-hardcoded` dans un worktree (`auto-i18n-hardcoded-batch-757b0ed9`). Claude a répondu immédiatement : **"Unknown command: /i18n-hardcoded"**. Aucune analyse du fichier n'a eu lieu.

## Cause racine

Le skill `i18n-hardcoded` n'est pas disponible dans le contexte du worktree. La liste des `slash_commands` dans l'event `init` ne contient pas `i18n-hardcoded` — il y a `batch`, `code-review`, `simplify` etc., mais pas les skills custom du projet night-shift.

Le worktree est un clone du repo cible (demarches-simplifiees), pas du repo night-shift. Les skills définis dans `.claude/skills/` de night-shift ne sont pas copiés/liés dans le worktree.

## Bien passé

- Le log stream-json est propre et diagnosticable
- Le Runner a correctement capturé le `no_diff` (pas de faux positif)

## Mal passé

- **Skill introuvable** : le Runner invoque `/i18n-hardcoded` mais le skill n'est pas disponible dans le worktree du repo cible
- **Pas de validation préalable** : le Runner ne vérifie pas que le skill existe avant de lancer la session
- **0 token utile** : la session a consommé un cold start pour rien

## Permissions bloquantes

Aucune — la session n'a même pas atteint le stade des permissions.

## Appris

1. Les skills custom night-shift ne sont PAS disponibles dans les worktrees des repos cibles — il faut soit les installer dans le repo cible, soit les passer en prompt inline
2. Le Runner devrait valider la disponibilité du skill avant le lancement (fail-fast avec message explicite)

## Actions

- [ ] **Runner** : ajouter un check pré-lancement qui vérifie que le skill est dans la liste `slash_commands` du repo cible, ou basculer sur un mode prompt inline (passer le contenu de SKILL.md directement au `-p`)
- [ ] **Worktree** : investiguer si on peut symlinkler `.claude/skills/` de night-shift dans le worktree cible, ou utiliser `--skill-path` si l'option existe
- [ ] **Backlog** : re-scan `application_mailer.rb` après fix du Runner
