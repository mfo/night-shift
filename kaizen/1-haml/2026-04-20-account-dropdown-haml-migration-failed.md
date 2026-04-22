---
status: traité
date_synth: 2026-04-20
---

# Kaizen — account_dropdown_component HAML migration (2026-04-20)

**Skill**: haml-migration | **Resultat**: failed (no_diff) | **Cout**: $0.68 | **Turns**: 31

## Ce qui s'est passe

Migration auto de `account_dropdown_component.html.haml`. L'agent n'a pas trouve le skill haml-migration dans le worktree, a improvise une migration manuelle, puis a boucle sur des permissions refusees (`rm`, `git rm`, `bun lint:herb`).

## Ce qui a bien marche

- ERB cree correctement
- i18n extrait (`via_france_connect`)
- Kaizen auto genere dans `tmp/kaizen.md`

## Ce qui a mal marche

1. **Skill introuvable** : le hook post-checkout ne copiait pas `.claude/skills/` quand `.claude/` existait deja (le repo a un `settings.json` committe). L'agent a improvise sans le SKILL.md.
2. **Permission `rm`/`git rm` bloquee (5 retries)** : l'agent boucle au lieu d'abandonner.
3. **Permission `bun lint:herb` bloquee (3 retries)**.
4. **HAML non supprime** → les deux templates coexistent → `no_diff`.

## Cause racine

Le hook post-checkout avait `[ ! -d "$claude_target" ]` — `.claude/` existait deja (avec juste `settings.json` du repo), donc la copie des skills etait sautee.

## Fixes appliques

- [x] Hook post-checkout : copie toujours `.claude/` par-dessus, meme si le repertoire existe
- [x] Skill haml-migration : ajout `Bash(bun lint:herb:*)`, `Bash(bundle exec erb_lint:*)` aux allowed-tools
- [x] Skill haml-migration : instruction `git mv` au lieu de `rm` + creation separee
- [x] Skill haml-migration : retrait de `Bash(rm:*)` et `Bash(git rm:*)` des allowed-tools
- [x] Hook redeploy dans le repo cible

## Learning pour le kaizen synth

Le kaizen auto avait identifie le symptome ("skill introuvable") mais pas la cause racine (condition du hook). Lors du synth, il faut **toujours verifier les logs claude** (`tmp/claude-{skill}.log` dans le worktree) et **remonter au code d'infra** (hooks, runner) quand le symptome est "fichier/skill introuvable".

## Ou trouver les logs

En cas de run auto, les logs Claude sont dans le worktree : `tmp/claude-{skill}.log` (format stream-json). Les kaizen auto sont dans `tmp/kaizen.md`.
