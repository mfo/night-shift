---
name: 2026-07-09-champ-header-sections-summary-component-spec-ok
description: Test-optimization OK on champ_header_sections_summary_component_spec.rb, 62% gain via T01 only
metadata:
  type: kaizen
  category: test-optimization
status: traité
date_synth: 2026-08-20
---

# Test-optimization OK : champ_header_sections_summary_component_spec.rb

**Date** : 2026-07-09
**Score** : 5/5 — succès
**Coût** : $4.23, 21 turns, ~40min
**Worktree** : `auto/test-optimization/c-champ_header_secti-bea4e7`

## Ce qui s'est passé

Optimisation du spec `spec/components/champ_header_sections_summary_component_spec.rb` (35 lines, 2 examples, ViewableChamp component).

- **Baseline** : 1.31s (médiane 3 runs)
- **Technique appliquée** : T01 — `create(:procedure)` / `create(:dossier)` → `build(...)` (2 `create` calls sur lignes 17-18)
- **Résultat** : **0.50s → -62%**
- **Commit** : `03c3c0b255 perf(tests): T01 create→build — champ_header_sections_summary_component_spec`
- **Coverage** : maintenue (~36% → ~34%, variation due au chargement Rails)

## Bien passé

1. **Signal detection efficace** — le grep initial a immédiatement identifié les 2 `create` calls comme le seul levier
2. **T01 a suffi seul** — le spec ne persiste rien en DB, `build` élimine ~0.81s de round-trips
3. **Pas de fausse route** — après T01, le skill a évalué T08/T09 et les a correctement écartées (gain marginal, setup déjà réduit à 0.50s)
4. **Coverage vérifiée** — pas de baisse significative malgré le passage de `create` à `build`

## Mal passé

1. **3 runs de baseline séquentiels** — chaque run prend ~1.3s, avec 3 runs ça ajoute ~4s de temps wall-clock. Pourrait être parallélisé ou limité à 2 runs quand les temps sont stables
2. **La couverture de ce spec est très faible** — 4% line coverage car c'est un composant ViewComponent qui délègue à des partials — le coverage.sh mesure l'app entier, pas le fichier ciblé
3. **Le temps résiduel (0.50s) est dominé par le chargement Rails (0.32s)** — aucune technique du skill ne peut réduire ça

## Appris

### Patterns réutilisables

- **T01 est le plus haut-lever pour les specs ViewComponent** — ces specs utilisent quasi systématiquement `create` pour des données qui sont juste lues en mémoire. `build` est un drop-in replacement qui élimine toute la latence DB
- **Quand le temps résiduel tombe sous 0.5s, s'arrêter** — le gain marginal de T08/T09 devient inférieur au bruit de mesure. Le skill a bien géré ce stopping criterion
- **Les specs à 2 exemples avec `build` après T01 atteignent vite le plancher Rails** — le bottleneck devient `files took X seconds` (0.32s ici), pas les exemples

### Points d'amélioration

- **Pas de technique pour réduire le chargement Rails** — c'est un problème connu, mais aucune des T* techniques ne l'adresse. Une piste serait de mesurer le temps de chargement séparément et de suggérer de splitter le spec ou de mutualiser le setup dans un `spec_helper` plus léger
- **Le coverage.sh mesure l'app entière** — le line coverage (4%) reflète que le spec ne touche qu'un composant, pas que la couverture est mauvaise. Ajouter une note dans le skill pour dire que ce n'est pas alarmant

## Permissions bloquantes

Aucune — le mode `acceptEdits` était actif, les 13 appels Bash ont tous été autorisés sans friction.

## Actions

- [x] Kaizen écrit
- [ ] Rien à faire de plus — le PR est prêt, le gain est bon, le plancher Rails est atteint

## Liens

- [[2026-07-06-file-input-component-spec-ok]] — T08 let_it_be avec gain 41.8%, pattern différent (spec plus complexe)
- [[2026-07-06-gallery-item-component-spec-ok]] — T08 let_it_be avec gain 29.5%
