---
name: test-optimization-procedures-controller-spec-failed
description: "Test-optimization no_diff on procedures_controller_spec.rb — skill absent du worktree cible"
metadata:
  type: kaizen
  category: test-optimization
status: traité
date_synth: 2026-08-20
---

# Test-optimization no_diff — procedures_controller_spec.rb (2026-07-16)

## Ce qui s'est passé

Session auto sur `spec/controllers/administrateurs/procedures_controller_spec.rb`. Le Runner a créé un worktree dans `/Users/mfo/dev/auto-test-optimization-batch-dc591624` (repo cible demarches-simplifiees-fr) puis invoqué `/test-optimization`. Résultat immédiat : "Unknown command: /test-optimization". 0 turns, 4ms, $0.

## Bien passé

- Session init propre, worktree créé correctement
- Coût nul (4ms, $0)
- Pas de permissions refusées ni de boucle

## Mal passé

- Le skill `/test-optimization` n'existe pas dans le repo cible (demarches-simplifiees-fr). Le `.claude/skills/` du worktree ne contient pas ce skill — il n'est installé que dans le repo night-shift.
- Échec immédiat et déterministe : 0 turn, pas de diagnostic ni de fallback.

## Appris

- Même pattern que [[test-optimization-procedures-controller-spec-failed-2026-07-11]] et la série i18n-hardcoded juillet 2026 : le skill est absent du worktree cible.
- Pour qu'un skill soit disponible dans un worktree cible, il faut soit (a) l'installer dans le repo cible, soit (b) passer par `claude -p` avec un prompt inline plutôt qu'un slash command, soit (c) copier le skill dans le worktree avant de lancer la session.
- La cause racine est identique pour test-optimization et i18n-hardcoded : le Runner utilise `/skill-name` (slash command), mais le repo cible n'a pas ce fichier skill.

## Permissions bloquantes

Aucune.

## Actions

1. **Court terme** : Dans `Skills::Runner`, avant de lancer `claude -p /<skill>`, vérifier si le skill existe dans le worktree cible. Si absent, copier le fichier skill depuis le repo night-shift ou utiliser un prompt inline (le contenu du SKILL.md).
2. **Moyen terme** : Proposer un mécanisme d'installation de skills dans le repo cible (ex: `nightshift install-skills` qui copie les skills déclarés dans la config).
3. **Long terme** : Envisager un mode "prompt inline" où le Runner envoie le contenu du SKILL.md directement plutôt que de dépendre d'un fichier skill sur le disque du worktree cible. Voir [[feedback_skill_maturity]] pour l'échelle de maturité.
