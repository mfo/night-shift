---
name: 2026-07-10-annotation-spec-ok
description: Flaky-test-fix OK sur annotation_spec.rb — Float::INFINITY, 50/50 verify, $1.76
metadata:
  type: kaizen
status: traité
date_synth: 2026-08-20
---

# flaky-test-fix OK — annotation_spec.rb

**Date** : 2026-07-10
**Skill** : flaky-test-fix
**Target** : `spec/graphql/annotation_spec.rb`
**Score** : 8/10 (1 fix direct, verify robuste mais couteux)

## Ce qui s'est passé

1. Le backlog a détecté un flaky sur `annotation_spec.rb` ligne 218 ("returns error") — merge queue count=1, retry count=0, 2 jobs CI
2. Le skill a lu le spec et le `.skill-context.json` pour identifier la cible exacte
3. Analyse de cause : `GraphQL::Schema::UniqueWithinType.encode('Champ', 123)` entre en collision avec un `TypeDeChamp` dont l'ID séquence atteint 123. Via `populate_stable_id`, l'ID DB devient le `stable_id` — `find_type_de_champ_by_stable_id('123')` trouve un type réel, la mutation réussit au lieu d'erreur
4. Fix : `123` → `Float::INFINITY` (ne peut jamais être un ID DB)
5. Verify : 50/50 runs pass — STABLE
6. Commit + PR description générée

## Bien passé

- **Analyze ciblée** : le `.skill-context.json` contenait juste assez d'infos (merge_queue_count, retry_count, lines, test_names) pour identifier la cause racine sans surcharge
- **Fix one-shot** : pas de boucle d'essai-erreur. La lecture du code source (`populate_stable_id`, `decode_typed_id`) a confirmé l'hypothèse avant d'éditer
- **Pattern robuste** : `Float::INFINITY` garantit qu'aucun ID DB ne peut entrer en collision — meilleur que `SecureRandom.uuid` ou un grand nombre car il ne peut pas être un entier DB valide
- **Verify automatisé** : le script `verify-flaky.sh` a tourné 50 runs sans intervention

## Mal passé

- **Verify coûteux** : 50 runs pour un fix trivial = $1.76. Une vérification de 5-10 runs suffirait pour ce type de collision évidente. Le coût domine le gain du fix
- **Worktree sale** : `.claude/settings.json` et `bun.lock` étaient déjà modifiés dans le worktree avant l'exécution du skill. Le commit a failli les inclure — la pipeline devrait `git reset --hard HEAD` ou créer un worktree frais
- **Pas de check coverage** : le kaizen ne mentionne pas si la couverture de tests a été vérifiée après le fix

## Appris

1. `Float::INFINITY` est le meilleur sentinel pour les IDs GraphQL factices — il est auto-documentant et ne peut pas être un entier DB
2. La vérification 50-run est disproportionnée pour les collisions simples. Proposer un mode `verify_effort: low` (5 runs) dans le skill
3. Le worktree doit être nettoyé (`git reset --hard HEAD`) avant chaque exécution pour éviter les commits pollués
4. Les tests GraphQL qui utilisent des IDs en dur (`123`, `999`) sont des candidats flaky probables dans les suites avec beaucoup de fixtures — le scanner pourrait les détecter statiquement

## Actions

1. [flaky-test-fix] Ajouter un paramètre `verify_runs` (défaut 50, mais le skill peut choisir moins pour les fixes triviaux)
2. [pipeline] Nettoyer le worktree avant chaque run : `git reset --hard HEAD && git clean -fd`
3. [flaky-test-fix patterns.md] Ajouter le pattern `Float::INFINITY` pour les IDs GraphQL factices
4. [scanner] Ajouter une détection statique des IDs en dur (`encode('.*', \d+)`) dans les specs GraphQL
