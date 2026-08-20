---
status: traité
date_synth: 2026-08-20
status: traité
date_synth: 2026-08-20
---

# Test-optimization failed — groupe_instructeurs_controller_spec.rb

**Date** : 2026-07-16
**Fichier** : `spec/controllers/administrateurs/groupe_instructeurs_controller_spec.rb`
**Reason** : no_diff
**Cost** : $0.00
**Turns** : 0

## Ce qui s'est passé

Le worktree a été créé (`auto-test-optimization-batch-dc591624`), Claude Code a été lancé, mais la commande `/test-optimization` a retourné "Unknown command". 0 tours exécutés, 0 tokens consommés, arrêt immédiat en 4ms.

## Bien passé

- Le scanner a correctement identifié le fichier via `glob('spec/**/*_spec.rb')`
- Pas de coût API perdu (4ms, $0)
- Aucune permission bloquante car rien n'a été exécuté

## Mal passé

- Même cause racine que les échecs du 2026-07-01, 2026-07-09, et 2026-07-11 : le skill `/test-optimization` n'est **pas installé** dans le repo cible (`démarches-simplifiées-fr`). Le worktree ne contient pas `.claude/skills/test-optimization/SKILL.md`.
- Le scanner est trop laxiste : il détecte n'importe quel `*_spec.rb` sans vérifier si le skill est disponible dans le repo cible. Résultat : des items backlog mort-nés.
- Pas de fail-fast : chaque item no_diff consomme une session worktree complète (setup + cleanup) pour 4ms de travail.

## Appris

- La condition `relevant?` (durée >= 5s) n'est jamais évaluée ici car le skill n'existe pas — le problème est en amont du pipeline.
- Le pattern de défaillance est identique à i18n-hardcoded juillet 2026 : le scanner du skill principal déclare des items que le repo cible ne peut pas traiter.
- 5 échecs no_diff consécutifs sur test-optimization en juillet 2026 : thumbnail, bottom-right-actions, procedures-controller, et maintenant groupe-instructeurs-controller.

## Permissions bloquantes

Aucune — la session s'est arrêtée avant toute interaction.

## Actions

1. **Ajouter un guard dans `Base#scan`** : vérifier que le skill cible existe dans `.claude/skills/<name>/SKILL.md` du repo cible avant d'émettre des items. Si absent, logger un warning et ignorer le fichier.
2. **Fail-fast batch** : quand un item du même batch échoue en no_diff avec la cause "Unknown command", annuler le reste du batch sans créer de worktrees.
3. **Réconciliation post-batch** : les 5 items no_diff test-optimization de juillet sont des artefacts morts — les marquer `skipped` dans la backlog ou les supprimer de la file.
