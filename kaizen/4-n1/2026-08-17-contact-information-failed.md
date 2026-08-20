---
name: 2026-08-17-contact-information-failed
description: n1-query-fix failed on contact_information.rb — context overflow deepseek-v4-flash, 63 turns, $4.69
---

# n1-query-fix: contact_information.rb — claude_error (context overflow)

## Ce qui s'est passé

Le skill `n1-query-fix` a été lancé en mode auto sur `app/models/contact_information.rb`. Le Runner a invoqué Claude Code dans un worktree (`auto-n1-query-fix-m-contact_information`) avec le prompt skill. La session a duré **63 turns**, **$4.69**, et s'est terminée sur une **API Error 400**: `Prompt has 100485 tokens, but the configured context size is 100000 tokens`.

## Ce qui a bien marché

- Setup Prosopite OK : bundle install réussi, gem installée
- Détection du N+1 : le skill a identifié que `procedures_controller_spec.rb` produit des N+1 queries impliquant `contact_information`
- Plusieurs patches tentés sur `procedure.rb` et `groupe_instructeur.rb` (includes/preloads)
- Boucle de verify : le skill a relancé rspec après chaque patch pour valider

## Ce qui n'a pas marché

1. **Context overflow** (100485 > 100000) : le modèle deepseek-v4-flash a un contexte de 100k tokens, atteint après 63 turns. La cause est l'accumulation de lectures de fichiers volumineux :
   - `procedure_revision.rb` (768 lignes) a été lu en entier
   - `procedure.rb` (probablement ~500+ lignes) a été lu
   - Les outputs rspec bruts ont été lus multiple fois
   - Les boucles de patch→verify→read ont saturé le contexte

2. **1 permission denied** : une commande `perl -pe 's/\e\[[0-9;]*[mK]//g' tmp/rspec-output.txt` a été rejetée (mode `acceptEdits`, sous-commande perl nécessitant approval). Le skill a ensuite utilisé `sed` à la place avec succès.

3. **Target inadapté** : `contact_information.rb` est un **model**, pas un **controller** — le skill est conçu pour les controllers. Il a contourné en utilisant `procedures_controller_spec.rb` comme spec de test, mais le fichier cible initial ne correspond pas au design du skill.

## Permissions bloquantes

- `perl` inline : la commande perl avec substitution regex a été rejetée car elle contient une sous-commande `perl -pe` non approuvée. Le skill s'est adapté en utilisant `sed` à la place.

## Actions

### Court terme

- **Augmenter le contexte ou réduire les tours** : pour deepseek-v4-flash (100k), limiter les reads de fichiers volumineux. Alternativement, configurer le Runner pour utiliser un modèle avec plus de contexte (opus 200k) quand le fichier cible est gros.

### Moyen terme

- **Détecter les fichiers model vs controller** : le scanner `N1QueryFix` devrait valider que le fichier cible est un controller (app/controllers/) avant de lancer le skill. Si c'est un model, soit le sauter (no_diff), soit adapter le prompt pour chercher les N+1 via les controllers qui utilisent ce model.

### Long terme

- **Compacter le contexte** : dans le skill n1-query-fix, après chaque patch→verify, le skill devrait `git commit` les changements et utiliser un worktree frais pour le prochain cycle plutôt que d'accumuler toute l'historique dans le même contexte.
- **Limiter les reads** : lire `procedure.rb` et `procedure_revision.rb` partiellement (seulement les associations et scopes pertinents) plutôt qu'en entier.

### Liens

- [[2026-07-20-procedures-controller-failed]] — même pattern de saturation contexte sur procedures_controller
- [[2026-07-08-procedure-clone-concern-failed]] — overflow similaire (100129 > 100000)
