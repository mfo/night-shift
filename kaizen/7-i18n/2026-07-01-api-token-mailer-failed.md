---
status: traité
date_synth: 2026-07-08
---

# Kaizen — i18n-hardcoded — api_token_mailer.rb — FAILED (no_diff)

**Date** : 2026-07-01
**Skill** : i18n-hardcoded
**Item** : app/mailers/api_token_mailer.rb
**Résultat** : no_diff (échec immédiat, 224ms, 0 token)

## Ce qui s'est passé

Le Runner a lancé `claude -p` dans le worktree cible (`/Users/mfo/dev/auto-i18n-hardcoded-batch-757b0ed9`) avec la commande `/i18n-hardcoded`. Claude a répondu `Unknown command: /i18n-hardcoded` en 224ms sans consommer aucun token API.

## Cause racine

Le skill `i18n-hardcoded` est défini dans le projet night-shift (`.claude/skills/i18n-hardcoded/`), mais la session Claude tourne dans le worktree du repo cible (demarches-simplifiees). Les skills night-shift ne sont pas disponibles dans ce contexte. La liste des skills chargés dans la session ne contient pas `i18n-hardcoded`.

## Bien passé

- Échec rapide (224ms, 0 token) — pas de gaspillage de contexte.
- Le log stream-json est clair et diagnosticable.

## Mal passé

- Le Runner invoque le skill via `/i18n-hardcoded` (slash command) au lieu d'injecter le prompt du skill directement via `claude -p --prompt`.
- Aucune vérification que le skill est disponible avant le lancement.
- Le résultat `is_error: false` avec `subtype: success` masque l'échec — le Pipeline voit un "succès" sans diff, d'où le `no_diff`.

## Appris

- Les skills night-shift ne sont PAS disponibles quand le Runner travaille dans un worktree d'un autre repo. Le Runner doit injecter le contenu du SKILL.md comme prompt, pas invoquer une slash command.
- Le code retour `no_diff` est un faux diagnostic : le vrai problème est `skill_not_found`. Il faudrait détecter "Unknown command" dans le résultat et remonter un FailureReason dédié.

## Permissions bloquantes

Aucune — l'échec est antérieur à toute interaction avec les fichiers.

## Actions

1. **Runner** : changer l'invocation pour passer le contenu de SKILL.md via `--prompt` ou `--system-prompt` au lieu d'utiliser la slash command `/i18n-hardcoded`.
2. **Pipeline** : détecter le pattern `Unknown command:` dans le résultat et remonter un `FailureReason::SkillNotFound` (ou similaire) au lieu de `no_diff`.
3. **Runner** (garde-fou) : vérifier que le skill est dans la liste des slash commands disponibles avant de lancer, ou basculer sur l'injection de prompt si absent.
