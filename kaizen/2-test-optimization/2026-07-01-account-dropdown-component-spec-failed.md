---
name: 2026-07-01-account-dropdown-component-spec-failed
description: "Test-optimization failed on account_dropdown_component_spec.rb: /test-optimization unknown command in target repo context"
metadata:
  type: kaizen
  score: 0
status: traité
date_synth: 2026-07-08
---

# Kaizen — Test-optimization FAILED sur account_dropdown_component_spec

## Ce qui s'est passé

Run autolearn du skill `test-optimization` sur `spec/components/account_dropdown_component_spec.rb`.
Échec immédiat : 144ms, 0 token API, 0 turn, $0.

Le Runner a envoyé `/test-optimization spec/components/account_dropdown_component_spec.rb` via `claude -p`.
Claude a répondu **"Unknown command: /test-optimization"** — le skill n'était pas enregistré comme slash command dans le contexte du repo cible.

### Diagnostic du log init

Dans l'event `init` du log, le skill apparaît dans `agents` mais PAS dans `skills` ni `slash_commands` :

| Liste | Contient test-optimization ? |
|---|---|
| `agents` | oui |
| `skills` | **non** |
| `slash_commands` | **non** |

## Bien passé

- Échec rapide (144ms) sans consommer de tokens — pas de gaspillage.
- Le log stream-json capture bien l'event init avec les listes de skills/agents, ce qui permet de diagnostiquer.

## Mal passé

- **Aucune optimisation tentée** : le skill n'a jamais démarré, donc no_diff est le résultat attendu.
- **Pas de détection amont** : le Runner ne vérifie pas si le skill est disponible comme slash command avant de lancer `claude -p`. L'erreur est découverte post-exécution.
- **Cause racine non identifiée** : pourquoi le skill est dans `agents` mais pas dans `skills` ? Hypothèses :
  1. Bug Claude Code : le skill loader détecte le SKILL.md (→ agent) mais échoue à l'enregistrer comme slash command
  2. Conflit de noms ou de paths entre skills globaux et skills projet
  3. Régression dans la version Claude Code 2.1.185

## Appris

1. **Un skill dans `agents` ≠ un skill invocable** : la présence dans la liste `agents` de l'event init ne garantit pas que `/skill-name` fonctionne comme slash command. Seule la liste `skills` ou `slash_commands` est fiable.
2. **Le Runner devrait valider la disponibilité** : avant de lancer `claude -p "/skill-name ..."`, vérifier que le skill est bien enregistré (via `claude --print-skills` ou parsing du init event).

## Permissions bloquantes

Aucune — le skill n'a jamais atteint le stade d'exécution.

## Actions

- [ ] **Investiguer le skill loader** : comprendre pourquoi `test-optimization` est dans `agents` mais pas `skills` dans le contexte du repo cible. Tester avec `claude --print-skills` dans le worktree.
- [ ] **Ajouter un pre-check au Runner** : avant `claude -p`, vérifier que le skill est dans la liste des slash commands disponibles. Si absent, fail-fast avec un message explicite (`SkillNotAvailable`).
- [ ] **Retenter manuellement** : relancer le run après résolution du problème de registration.
