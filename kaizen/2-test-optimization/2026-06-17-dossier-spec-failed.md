---
name: test-optimization-dossier-spec-failed
description: Test-optimization skill failed on dossier_spec.rb due to context window overflow on deepseek-v4-flash
metadata:
  type: kaizen
  iteration: 2
status: traité
date_synth: 2026-07-08
---

# Kaizen : Test-optimization échoué sur dossier_spec.rb

## Ce qui s'est passé

Le skill `test-optimization` a été lancé en mode auto sur `spec/models/dossier_spec.rb` (projet demarches-simplifiees.fr). La session a duré 19 turns, coûté $1.28, et échoué avec une **API Error 400** : `Prompt has 100129 tokens, but the configured context size is 100000 tokens`.

## Bien passé

- **Profiling baseline complet** : 3 runs réussis (31.84s, 31.96s, 32.08s → médiane ~31.96s). Coverage baseline : 56.57%.
- **Spring démarré** correctement après un premier échec (le `spring start` initial n'a pas trouvé de PID).
- **10 Bash calls** et **4 Read calls** ont tous réussi — pas de permissions bloquantes.
- **0 permission denied** — le skill a pu lire les fichiers et lancer les commandes sans interférence.

## Mal passé

1. **Context window overflow** : la session a atteint 100129 tokens contre une limite de 100000. Le fichier `dossier_spec.rb` fait 2000+ lignes (~26k tokens). En cumulant les instructions du skill, les patterns, les résultats des 4 runs spec + coverage, et le fichier spec complet, le contexte a débordé pendant la phase d'analyse/thinking.
2. **Aucune optimisation appliquée** : 0 appels Edit/Write. Tout le travail de profiling a été fait mais la phase de transformation a échoué avant de commencer.
3. **Modèle deepseek-v4-flash** : sa limite de contexte est 100k tokens. Le skill test-optimization charge beaucoup de documents (SKILL.md, patterns.md, quickstart.md, le fichier spec entier, les logs des runs) — cumulé, ça dépasse facilement la limite.
4. **Memory paths mal alignés** : la session utilisait le memory path de `demarches-simplifiees-fr` (le projet cible) mais pas celui de `night-shift` (le projet méta). Les mémoires de night-shift (patterns, feedback) n'étaient pas chargées.

## Appris

- **Les specs > 1500 lignes sont dangereuses** avec un modèle à 100k tokens. `dossier_spec.rb` est un cas extrême mais pas unique.
- **Le skill devrait lire le fichier spec en plusieurs passes** (d'abord le top pour les `describe`/`let`, puis les sections une par une) plutôt qu'en une seule Read.
- **La phase d'analyse est la plus consommatrice** : l'agent commence à réfléchir à des optimisations, génère du thinking long, et le cumul des résultats précédents + le nouveau thinking fait déborder.
- **Le warm-up run a mis 40s** (vs ~32s les runs réels) — le temps de chargement Rails/Spring varie.
- **La spec a des `let_it_be` déjà utilisées** dans plusieurs describe (by_statut, avis_for, etc.) — le skill doit les détecter et ne pas les dupliquer.

## Permissions bloquantes

Aucune. Tous les appels Bash et Read ont été autorisés.

## Actions

### Court terme (immédiat)

1. **Ajouter un check de taille de fichier spec** dans le quickstart ou le SKILL.md du skill test-optimization :
   - Si le fichier > 1500 lignes OU > 30k tokens estimé, lire en 2 passes (d'abord les `describe`/`let`/`it` en tête, puis les sections par offset)
2. **Augmenter la limite de contexte** dans la config du skill : passer de 100k à 200k tokens (deepseek-v4-flash supporte 200k selon la doc). Vérifier que le paramètre `contextWindow` est bien utilisé.

### Moyen terme

3. **Évaluer la viabilité de deepseek-v4-flash pour ce skill** : le gain coût ($1.28 pour juste le profiling sans optimisation) vs Opus 4.8 qui a 200k de contexte et coûte plus cher par token mais réussit la session complète.
4. **Split `dossier_spec.rb` en sous-fichiers** (T12 du pattern catalogue) — le skill peut le faire mais ça demande plus de contexte. Le faire manuellement réduira le besoin de contexte de chaque session future.

### Long terme

5. **Instrumenter le skill** pour qu'il détecte la taille du fichier avant de le lire et choisisse la stratégie de lecture adaptée.
