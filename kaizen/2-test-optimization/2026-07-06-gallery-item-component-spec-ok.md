---
name: 2026-07-06-gallery-item-component-spec-ok
description: Test-optimization OK on gallery_item_component_spec.rb — 29.5% gain via T08 let_it_be, T09 reverted
metadata:
  type: kaizen
status: traité
date_synth: 2026-07-08
---

# Test-optimization — GalleryItemComponent spec OK

## Ce qui s'est passé

Run autolearn sur `spec/components/attachment/gallery_item_component_spec.rb` (14 examples, baseline 4.94s médian).

### Techniques appliquées

| Technique | Résultat |
|---|---|
| T08 — `let_it_be` | Appliqué : 4 objets read-only convertis (`procedure`, `types_de_champ_public`, `types_de_champ_private`, `instructeur`). 4.94s → 3.48s, gain **29.5%** |
| T09 — `aggregate_failures` | Testé, gain marginal ~2%, **revert** — le setup économisé (`touch(:depose_at)`) est trop léger pour justifier la perte de granularité |
| T01 — `create→build` | Non tenté — les 7 `create` sont pour `dossier` (DB-bound, pas de `build_stubbed` disponible) |

**Final** : 3.48s, 14 examples, 0 failures. Coverage inchangée (41.09%).

### Tours économisés

- Détection initiale rapide : 3 runs baseline en parallèle, pas de warmup wasted
- T08 seul suffit : pas besoin d'empiler 3+ techniques sur ce fichier
- T09 reverted après 3 runs de confirmation : pas de fausse optimisation

## Bien passé

1. **T08 seul a donné ~30%** — ratio gain/travail excellent (4 let→let_it_be, 4 lignes changées)
2. **Revert rapide de T09** — détecté dès le 3e run que le gain était sous le bruit de mesure, pas insisté
3. **Aucun bug squatté** — pas de mutation leaking ni d'order-dependency. `let_it_be` sur objets read-only est safe
4. **Couverture stable** — identique avant/après, pas de régression
5. **PR description complète** — baseline, gain, techniques retenues/non retenues documentées

## Mal passé

1. **T09 a coûté 4 runs de validation** pour un gain nul — le seuil de rejet pourrait être plus précoce (dès 1 run si delta < seuil)
2. **Pas de warmup run** explicite avant la baseline — les runs incluent le chargement Spring dans le temps mesuré (files took 0.46s), ce qui ajoute du bruit

## Appris

- **`let_it_be` reste le levier #1** sur les specs avec setup DB lourd : 4 lignes changées → 30% de gain. Priorité absolue
- **aggregate_failures a un ROI faible** quand les `it` partagent un setup minimal (1 `touch`). Nettement moins efficace que sur des specs avec 5+ lignes de `before` partagé
- **Ce fichier n'a pas de `build_stubbed`** ni de `create` vers `build` possible — la factory `dossier` cascade trop. Le pattern "create→build" n'est pas applicable ici
- **14 examples → 12 après merge T09** : la fusion de `it` pairs réduit le nombre d'examples mais n'accélère pas quand le goulot est DB, pas le setup mémoire

## Permissions bloquantes

Aucune — `acceptEdits` mode, pas de permissions refusées.

## Actions

1. **Aucune** — succès complet, le diff est déjà committed
2. **Pattern à généraliser** : pour les specs ViewComponent avec setup `procedure` + `dossier`, T08 est le premier diagnostic à essayer. Les objets `types_de_champ_public/private` sont toujours read-only et candidats naturels
3. **Pour le skill** : ajouter une heuristique "si T09 merge < 2 it blocks ou setup < 2 lignes, skip direct — pas de run de validation" → économise 4 runs × ~5s = 20s par fichier
