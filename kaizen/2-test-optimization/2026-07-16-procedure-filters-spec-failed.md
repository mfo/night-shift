---
status: traité
date_synth: 2026-08-20
status: traité
date_synth: 2026-08-20
---

# Test-optimization — procedure_filters_spec.rb (no_diff)

**Date** : 2026-07-16
**Log** : `tmp/logs/2026-07-16-test-optimization-procedure-filters-spec.log`
**Item** : `spec/system/instructeurs/procedure_filters_spec.rb`
**Cost** : $0
**Turns** : 0
**Cause racine** : `/test-optimization` = Unknown command dans le worktree cible

## Ce qui s'est passé

Le Runner a lancé `claude -p '/test-optimization spec/system/instructeurs/procedure_filters_spec.rb'` dans un worktree du repo cible (demarches-simplifiees-fr). Claude Code a immédiatement répondu "Unknown command: /test-optimization" car ce slash command n'existe pas dans la config du worktree cible. 0 turn, 4ms, $0.

## Bien passé

- Rien — le skill n'a pas démarré, 0 turn, pas de coût gaspillé.

## Mal passé

- **Même cause racine que les précédents échecs no_diff** : le skill `/test-optimization` n'est pas installé dans le repo cible.
- La session a été créée dans un worktree du repo cible (`auto-test-optimization-batch-*`) qui n'a pas les skills nightshift.
- Aucune vérification de disponibilité du skill avant lancement.

## Appris

- C'est le **5ème échec no_diff consécutif** pour test-optimization avec la même cause racine (voir kaizen 2026-07-09-thumbnail, 2026-07-09-bottom-right-actions, 2026-07-11-procedures-controller, 2026-07-16-procedures-controller).
- Le pattern est identique aux échecs i18n-hardcoded de juillet : le skill n'existe pas dans le repo cible.
- La solution proposée dans le kaizen du 2026-07-16 (procedures-controller) reste valide : soit copier le skill dans le repo cible, soit passer par un prompt inline dans le Runner plutôt qu'un slash command.

## Permissions bloquantes

- Aucune permission n'a été demandée — le skill n'a pas démarré.

## Actions

1. **Court terme** : Ajouter une vérification de disponibilité du skill dans le BacklogSource (`Nightshift.skills_available_in_worktree?`) avant de lancer le Runner, pour éviter les lancements à blanc.
2. **Moyen terme** : Implémenter la stratégie de fallback — si le slash command est inconnu, le Runner peut injecter le prompt du skill directement (via `claude -p "$(cat .claude/skills/test-optimization/SKILL.md) ..."`) sans dépendre de sa disponibilité dans le repo cible.
3. **Long terme** : Envisager de packager les skills nightshift dans une gem/plugin installable dans le repo cible via `claude-code --install-plugin`.
