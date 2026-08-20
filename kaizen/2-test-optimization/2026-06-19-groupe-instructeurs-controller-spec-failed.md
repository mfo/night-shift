---
name: test-optimization-groupe-instructeurs-controller-spec-failed
description: Test-optimization skill failed on groupe_instructeurs_controller_spec.rb due to context window overflow on deepseek-v4-flash (same root cause as dossier-spec and graphql-controller)
metadata:
  type: kaizen
  iteration: 4
status: traité
date_synth: 2026-07-08
---

# Kaizen : Test-optimization échoué sur groupe_instructeurs_controller_spec.rb

## Ce qui s'est passé

Le skill `test-optimization` a été lancé en mode auto sur `spec/controllers/administrateurs/groupe_instructeurs_controller_spec.rb` (projet demarches-simplifiees.fr). La session a duré **48 turns**, coûté **$3.16**, et échoué avec une **API Error 400** : `Prompt has 100409 tokens, but the configured context size is 100000 tokens`.

Contrairement aux deux échecs précédents (dossier-spec et graphql-controller), cette session a **appliqué et commité une optimisation** avant de mourir.

## Bien passé

- **Profiling baseline complet** : 3 runs réussis (34.34s, 41.04s, 29.76s → médiane 34.34s). Coverage baseline : 52.22%.
- **Optimisation T10 appliquée** : `procedure2` et `gi_2_2` déplacés du top-level dans le contexte `#reaffecter` "when the target group is not a possible group" → gain de **26.5%** (34.34s → 25.23s médian). Commité avec succès.
- **T09 essayé puis rollbacké** : merge de 2 `it` dans `#add_instructeurs` — pas de gain mesurable (25.23 → 25.29, noise), rollbacké proprement.
- **0 permission denied** : 31 tool calls (Bash, Read, Grep, Edit) tous autorisés. Aucun fichier introuvable, aucune boucle/retry.
- **48 turns productifs** : l'agent a progressé linéairement — profiling → analyse → implémentation → mesure → rollback → prochaine optimisation — jusqu'au débordement.

## Mal passé

1. **Context window overflow (identique aux 2 échecs précédents)** : 100409 > 100000 tokens sur deepseek-v4-flash. Le skill cumule SKILL.md, patterns.md, quickstart.md, le spec complet, les logs des runs, le thinking d'analyse, et les résultats intermédiaires. La limite 100k est insuffisante.

2. **Optimisation partielle** : la session a appliqué T10 (gain 26.5%) et commencé l'analyse de `gi_1_3` dans #reaffecter (T10 aussi) quand le contexte a débordé. **L'optimisation commitée est appliquée dans le worktree** mais le cycle de mesure complet n'a pas été finalisé.

3. **Coût élevé : $3.16 pour un gain partiel** — c'est la session la plus chère des 3 échecs (dossier-spec $1.28, graphql-controller $2.57). 75 minutes de temps machine pour 26.5% de gain sur un fichier spec.

4. **Spring a causé des faux positifs** : après l'optimisation T10, les temps étaient 2x plus longs (66-71s au lieu de 34s). L'agent a diagnostiqué que Spring était en mauvais état et a relancé sans Spring — 20.85s, puis 23.18s. Ce diagnostic a coûté ~5-6 turns et ~$0.50-0.80 de contexte.

5. **Les actions des 2 kaizen précédents n'ont pas été appliquées** : check de taille de fichier, lecture en 2 passes, augmentation du contexte à 200k. **3ème occurrence consécutive** du même pattern d'échec.

## Appris

- **Le problème est systémique et confirmé par 3 échecs** : `dossier_spec.rb` (19 turns, $1.28), `graphql_controller_spec.rb` (51 turns, $2.57), `groupe_instructeurs_controller_spec.rb` (48 turns, $3.16). Tous échouent à cause de la même limite 100k tokens sur deepseek-v4-flash. **C'est la 3ème occurrence consécutive, le fix doit être prioritaire.**

- **Le skill peut produire des résultats même avec un overflow** : cette session a commité un gain de 26.5% avant de mourir. Mais l'optimisation est partielle — d'autres opportunités (T09 rollbackée, T10 non-finie, gi_1_3 pas optimisée) n'ont pas été appliquées.

- **Spring instable** : Spring peut entrer dans un état dégradé après des modifications de spec (DB pollution, rechargement). Le diagnostic Spring est coûteux en contexte. Le skill devrait détecter et gérer ce cas (run sans Spring comme fallback direct).

- **Le coût croît avec le nombre de turns** : chaque turn ajoute du contexte (nouveau thinking + résultats intermédiaires). Les sessions qui progressent linéairement (comme celle-ci) sont les plus coûteuses car elles atteignent le overflow avec plus de turns et plus de données accumulées.

## Permissions bloquantes

Aucune. Tous les appels Bash, Read, Grep, Edit ont été autorisés.

## Actions

### Court terme (immédiat) — PRIORITAIRE : appliquer les actions des 3 kaizen

1. **Augmenter la limite de contexte de 100k à 200k** dans la config du skill `test-optimization` (`SKILL.md` ou `quickstart.md`). deepseek-v4-flash supporte 200k tokens (`contextWindow: 200000`). Le paramètre actuel limite à 100k — soit le skill force une limite inférieure, soit la config du projet la bride.

2. **Ajouter un check de taille de fichier spec** avant de commencer :
   - Si le fichier > 1500 lignes OU > 30k tokens estimé, lire en 2 passes (d'abord les `describe`/`let`/`it` en tête, puis les sections par offset)
   - Si le fichier > 3000 lignes, suggérer un split (T12) avant l'optimisation

3. **Réduire le volume chargé dans le contexte initial** : ne pas charger `SKILL.md` + `patterns.md` + `quickstart.md` + `checklist.md` en une seule fois. Charger le quickstart d'abord, puis les patterns à la demande pendant l'analyse.

### Moyen terme

4. **Instrumenter le skill pour détecter Spring instable** : après chaque modification de spec, faire un warm-up run. Si le temps > 2x baseline, relancer sans Spring et comparer. Ajouter un check `spring status` avant de commencer.

5. **Évaluer Opus 4.8** pour les specs > 1500 lignes : son contexte 200k tient la session entière. Comparer TCO : deepseek-v4-flash à $3.16 sans résultat complet vs Opus 4.8 à ~$5-8 mais qui termine en 1 session.

### Long terme

6. **Couper les specs longues en sous-fichiers** (T12 du pattern catalogue) : les fichiers > 1000 lignes devraient être scindés par contexte/describe. Cela réduit le volume par session et permet un traitement parallèle.
