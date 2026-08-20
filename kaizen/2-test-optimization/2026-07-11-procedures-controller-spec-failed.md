---
name: test-optimization-procedures-controller-spec-failed
description: "Test-optimization no_diff: /test-optimization inconnu dans le worktree cible, 0 turn, $0"
metadata:
  type: feedback
  project: nightshift
status: traité
date_synth: 2026-08-20
---

# Test-optimization failed — procedures_controller_spec.rb

**Date**: 2026-07-11
**Skill**: test-optimization
**Target**: `spec/controllers/instructeurs/procedures_controller_spec.rb`
**Failure reason**: no_diff
**Cost**: $0.00 (0 turns)

## Ce qui s'est passé

Le Reconciler a claim un backlog item pour `procedures_controller_spec.rb`, créé un worktree dans `auto-test-optimization-batch-cad7aa68`, et lancé Claude avec la commande `/test-optimization`. Claude a immédiatement répondu "Unknown command: /test-optimization" car le skill n'est pas chargé dans ce worktree — le projet cible (démarches simplifiées) n'a pas le skill dans ses `.claude/skills/`. 0 turns, 0 diff, session terminée en 4ms.

## Bien passé

- Rien. 0 turns, 0 diff, 0 permissions refusées, mais $0 de perte.

## Mal passé

- **Cause racine** : le worktree cible n'a pas le skill `/test-optimization`. Le projet démarches-simplifiées n'a pas de fichier `.claude/skills/test-optimization/SKILL.md`. Le slash command est inconnu.
- **Aucune tentative** : pas de retry, pas de boucle d'analyse. Le skill n'a pas été invoqué du tout.
- **Pas de message d'erreur exploitable** : le log montre juste une session de 1 turn avec "Unknown command".

## Permissions bloquantes

Aucune — le skill n'a jamais été lancé.

## Appris

1. **Même pattern que i18n-hardcoded** : les no_diff du 2026-07-01 (administration-mailer, api-token-mailer, etc.) avaient la même cause racine — slash command inconnue dans le worktree cible. Ce n'est pas un faux positif scanner mais un problème d'installation de skill.

2. **Le vrai problème est en amont** : le BacklogSource (TestOptimization) scanne le repo cible et trouve des fichiers `.spec` qu'il estime optimisables, mais le skill `/test-optimization` n'est pas disponible dans ce repo. Le scanner ne vérifie pas si le skill existe avant de créer un backlog item.

3. **Solution** : soit (a) installer le skill dans le repo cible (copier `.claude/skills/test-optimization/`), soit (b) ajouter un check dans le scanner ou le pipeline pour détecter qu'un slash command est inconnu avant de créer l'item, soit (c) faire du `claude -p /test-optimization` un appel avec `--allowed-tools` ou via le Runner qui injecte le skill depuis nightshift.

## Actions

- [ ] Ajouter un check `Runner.available?("/test-optimization")` dans `BacklogSources::TestOptimization#scan` ou dans `Reconciler#launch_skill` pour skip les items où le skill est absent
- [ ] Alternative rapide : copier les skills dans le repo cible avec un symlink ou un script `bin/install-skills`
- [ ] Marquer ce backlog item comme skipped (pas retryable — le problème est structurel, pas transient)
- [ ] Vérifier si flaky-test-fix et n1-query-fix ont le même problème (probablement oui — tous les skills sont dans nightshift, pas dans les repos cibles)
