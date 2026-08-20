---
name: test-optimization-graphql-controller-spec-failed
description: Test-optimization skill failed on graphql_controller_spec.rb due to context window overflow on deepseek-v4-flash (same root cause as dossier-spec)
metadata:
  type: kaizen
  iteration: 3
status: traité
date_synth: 2026-07-08
---

# Kaizen : Test-optimization échoué sur graphql_controller_spec.rb

## Ce qui s'est passé

Le skill `test-optimization` a été lancé en mode auto sur `spec/controllers/api/v2/graphql_controller_spec.rb` (projet demarches-simplifiees.fr). La session a duré 51 turns, coûté **$2.57**, et échoué avec une **API Error 400** : `Prompt has 102331 tokens, but the configured context size is 100000 tokens`. Le skill a fait une analyse approfondie (lecture des types GraphQL, évaluation de stratégies `let_it_be`, détection des overrides de `procedure`) mais la phase de transformation a échoué — aucune optimisation appliquée.

## Bien passé

- **Profiling complet** : le skill a lu le fichier spec, analysé les types GraphQL (DemarcheType, DossierType, etc.), et exploré plusieurs stratégies d'optimisation.
- **0 permission denied** : aucun appel Bash/Read/Edit bloqué.
- **51 turns productifs** : l'agent a identifié les patterns de création coûteux (`create(:deleted_dossier)` cascade, overrides de `procedure` par contexte).
- **Aucune boucle/retry** : le skill n'est pas resté bloqué sur une étape — il a progressé linéairement jusqu'au débordement.

## Mal passé

1. **Context window overflow (identique au dossier-spec)** : 102331 > 100000 tokens sur deepseek-v4-flash. Le skill charge trop de contenu simultanément (SKILL.md, patterns.md, quickstart.md, le spec entier + les types GraphQL lus, le thinking d'analyse, les résultats des runs). La limite 100k est insuffisante pour ce volume de travail.

2. **Cost élevé sans résultat** : $2.57 consommé pour zero optimisation appliquée. C'est 2x le coût du dossier-spec ($1.28) car la session a fait plus de turns d'analyse avant de mourir.

3. **Aucun Edit/Write appliqué** : comme le dossier-spec, la phase de transformation n'a pas démarré. Le skill fait analyse → décision → application, et le overflow arrive pendant la phase d'analyse (thinking long + résultats intermédiaires).

4. **Les actions du précédent kaizen n'ont pas été appliquées** : le check de taille de fichier spec, la lecture en 2 passes, et l'augmentation du contexte à 200k n'ont pas été implémentés. Cette session prouve que le problème est récurrent et non isolé à un fichier.

## Appris

- **Le problème est systémique, pas spécifique à un fichier** : `dossier_spec.rb` (2000+ lignes) et `graphql_controller_spec.rb` (taille inconnue mais les types GraphQL ajoutent du volume) échouent tous les deux. Le skill a un défaut de conception : il charge tout le contexte nécessaire AVANT de commencer les optimisations, et le cumul dépasse 100k.

- **La spec graphql_controller est particulièrement coûteuse en analyse** : l'agent lit les types GraphQL (DemarcheType, DossierType, etc.) en plus du spec lui-même. Cela ajoute ~10-20k tokens au contexte avant même d'avoir commencé les optimisations.

- **Le warm-up du dossier-spec n'est pas reproduit ici** : pas de message "Spring démarré" ou de runs de profiling visibles — le skill est peut-être passé directement à l'analyse sur ce fichier, ou le warm-up était inclu dans le contexte.

## Permissions bloquantes

Aucune. Tous les appels Bash, Read, Grep ont été autorisés.

## Actions

### Court terme (immédiat)

1. **Appliquer les actions du kaizen dossier-spec** : ajouter le check de taille de fichier dans le quickstart/SKILL.md du skill test-optimization, et augmenter la limite de contexte de 100k à 200k. Le paramètre `contextWindow` dans la config du skill doit être vérifié — deepseek-v4-flash supporte 200k tokens.

2. **Réduire le volume chargé avant analyse** : modifier le SKILL.md pour que la lecture du spec soit différée — lire d'abord les `describe`/`let`/`it` (top ~30 lignes), analyser, puis lire les sections par offset. Ne pas charger les types GraphQL associés (comme `app/graphql/types/dossier_type.rb`) en une seule Read.

### Moyen terme

3. **Couper la spec en sous-fichiers** (T12 du pattern catalogue) : `graphql_controller_spec.rb` pourrait être scindée par resolver (demarche_query, dossier_query, mutations). Cela réduit le volume par session et permet un traitement parallèle.

4. **Évaluer Opus 4.8** : son contexte 200k permettrait de tenir, mais le coût par token est plus élevé. Faire un test avec un fichier de taille moyenne pour comparer le TCO (Opus finit en 1 session à 200k vs deepseek échoue en 51 turns à $2.57 sans résultat).

### Long terme

5. **Instrumenter le skill** pour qu'il choisisse la stratégie de lecture adaptée à la taille du fichier cible, et qu'il estime le contexte nécessaire avant de commencer.
