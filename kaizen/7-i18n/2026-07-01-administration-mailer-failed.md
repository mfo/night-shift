# Kaizen — i18n-hardcoded — administration_mailer.rb — FAILED (no_diff)

**Date** : 2026-07-01
**Skill** : i18n-hardcoded
**Cible** : `app/mailers/administration_mailer.rb`
**Outcome** : no_diff (0 tour, 0 token, 0 USD)

## Ce qui s'est passe

Le Runner a lance `claude -p` dans le worktree `auto-i18n-hardcoded-batch-757b0ed9`. Claude a recu le prompt et a tente d'executer `/i18n-hardcoded` comme slash command. Reponse immediate : `Unknown command: /i18n-hardcoded`.

La session s'est terminee en 186ms avec 0 tour d'API.

## Cause racine

Le skill `i18n-hardcoded` n'est pas dans la liste `slash_commands` du worktree. Le worktree est une copie du repo cible (demarches-simplifiees-fr), pas du repo night-shift. Les skills night-shift ne sont pas disponibles dans ce contexte.

Liste des skills disponibles dans le worktree (extrait du log init) :
- `create-pr`, `til`, `deep-research`, `update-config`, `verify`, `debug`, `code-review`, `simplify`, `batch`, etc.
- **Absent** : `i18n-hardcoded`, `haml-migration`, `test-optimization`, `n1-query-fix`, `harden-*`

## Bien passe

- Echec rapide (186ms, 0 token) — pas de gaspillage de contexte.
- Le log stream-json est lisible et suffisant pour diagnostiquer.

## Mal passe

- **Le Runner envoie le prompt comme slash command** (`/i18n-hardcoded`) au lieu d'injecter le contenu du skill directement dans le prompt `-p`.
- Aucun mecanisme de detection cote Runner : le `no_diff` ne distingue pas "pas de changement necessaire" de "le skill n'a meme pas demarre".
- Pas de validation pre-run que le skill est disponible dans l'environnement cible.

## Appris

1. **Les skills Night Shift ne sont pas portables** : ils n'existent que dans le repo night-shift. Le Runner doit soit injecter le prompt du skill via `-p` (pas `/skill`), soit s'assurer que les skills sont symlinkes/copies dans le worktree.
2. **`no_diff` est un faux diagnostic** : ici il n'y a pas eu d'execution du tout. Il faudrait un statut `skill_not_found` ou `no_execution` distinct.

## Permissions bloquantes

Aucune — le skill n'a meme pas demarre.

## Actions

| # | Action | Priorite |
|---|status: traité
date_synth: 2026-07-08
--------|----------|
| 1 | **Verifier comment le Runner invoque le skill** : `Runner.run` doit passer le contenu de `SKILL.md` via `--prompt` ou `--system-prompt`, pas comme slash command | P0 |
| 2 | **Ajouter un statut d'echec `SkillNotFound`** dans `FailureReason` pour distinguer ce cas de `no_diff` | P1 |
| 3 | **Pre-check dans Runner** : valider que le skill est resolvable avant de lancer `claude -p` | P2 |
