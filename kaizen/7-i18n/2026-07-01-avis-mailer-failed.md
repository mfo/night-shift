---
status: traité
date_synth: 2026-07-08
---

# Kaizen — i18n-hardcoded — avis_mailer.rb — FAILED (no_diff)

**Date** : 2026-07-01
**Skill** : i18n-hardcoded
**Cible** : `app/mailers/avis_mailer.rb`
**Outcome** : no_diff (0 tour, 0 token, 0 USD)

## Ce qui s'est passe

Le Runner a lance `claude -p` dans le worktree `auto-i18n-hardcoded-batch-757b0ed9`. Claude a recu le prompt et a tente d'executer `/i18n-hardcoded` comme slash command. Reponse immediate : `Unknown command: /i18n-hardcoded`. Session terminee en 165ms, 0 tour d'API.

Meme batch et meme cause racine que `administration_mailer.rb` et `api_token_mailer.rb`.

## Cause racine

Le skill `i18n-hardcoded` n'existe pas dans le worktree cible (demarches-simplifiees-fr). Les skills Night Shift ne sont pas copies/symlinkes dans le worktree. Le Runner invoque le skill comme slash command (`/i18n-hardcoded`) au lieu d'injecter le contenu de `SKILL.md` via `--prompt`.

## Bien passe

- Echec rapide (165ms, 0 token) — aucun gaspillage.
- Log stream-json suffisant pour diagnostiquer.

## Mal passe

- **Invocation par slash command** : le Runner utilise `/i18n-hardcoded` qui n'est resolvable que dans le repo night-shift, pas dans le worktree du repo cible.
- **`no_diff` masque le vrai probleme** : pas de distinction entre "skill pas demarre" et "skill execute sans diff".
- **3 items du meme batch echouent pour la meme raison** : pas de fail-fast au niveau du batch quand le premier item echoue sur `Unknown command`.

## Appris

1. **Tout le batch i18n-hardcoded du 2026-07-01 est impacte** par le meme bug Runner. Aucun item n'a pu demarrer.
2. **Le Runner doit injecter le prompt du skill** via `--prompt` ou `--system-prompt`, pas comme slash command — les skills ne sont pas portables entre repos.
3. **Un fail-fast batch** eviterait de relancer N fois un skill quand le premier echec est structurel (meme erreur, meme cause).

## Permissions bloquantes

Aucune — le skill n'a pas demarre.

## Actions

| # | Action | Priorite |
|---|--------|----------|
| 1 | **Fix Runner : injecter le skill via `--prompt`** au lieu de `/skill` — cf. actions du kaizen `administration-mailer-failed` | P0 |
| 2 | **Ajouter `SkillNotFound` a `FailureReason`** pour distinguer de `no_diff` | P1 |
| 3 | **Fail-fast batch** : si le 1er item echoue sur `Unknown command`, avorter le batch entier | P1 |
