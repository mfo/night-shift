---
name: 2026-07-09-thumbnail-component-spec-failed
description: Test-optimization no_diff on thumbnail_component_spec.rb — 38 lines, 2 examples, gain 0.08s sous seuil
metadata:
  type: kaizen
status: traité
date_synth: 2026-08-20
---

# Test-optimization failed: Attachment::ThumbnailComponent spec

**Date :** 2026-07-09
**Fichier :** `spec/components/attachment/thumbnail_component_spec.rb`
**Skill :** `/test-optimization`
**Raison :** `no_diff`
**Coût :** $1.95, 15 turns, 1.29s

## Ce qui s'est passé

Le skill a été lancé en mode auto sur le fichier thumbnail_component_spec.rb. Il a profité la baseline (1.09s median, 3 runs), appliqué T08 (let_it_be) sur les fixtures, puis mesuré le gain : 0.08s (7.3%). Sous le seuil de 0.5s requis pour commit. Aucune autre technique applicable (T01, T04, T09, T10, T12). PR description écrite, diff annulé.

## Ce qui a bien marché

- Profiling baseline réussi (2 runs, median 1.09s)
- T08 appliquée proprement
- Le skill a correctement identifié que le gain était insuffisant et rollbacké

## Ce qui a mal marché

1. **Spring indisponible** — le background `spring start` a été refusé (permission `&`). Le warm-up via `spring rspec` a échoué (server pas lancé). Le skill est passé en mode sans Spring, ce qui ralentit chaque run.
2. **3 permissions refusées** — `spring start &`, `COVERAGE=true bundle exec rspec`, `NO_COVERAGE=true bundle exec rspec`. Le coverage baseline n'a pas pu être mesurée.
3. **Fichier trop petit pour gain significatif** — 38 lignes, 2 examples. Même avec let_it_be, le setup DB (procedure + dossier + upload) domine le temps.

## Appris

- Les fichiers < 50 lignes / < 3 examples ne valent pas la peine d'être optimisés en mode auto. Le coût fixe du skill ($1.95) dépasse le bénéfice attendu.
- Le seuil de commit (gain >= 5% ET >= 0.5s) est correct : il évite de polluer le git pour des micro-gains.
- Le `file` fixture upload avec `fixture_file_upload` est un cas connu : l'IO stream est consumé au premier use, `let_it_be` cause `ActiveStorage::IntegrityError`. Pas une régression du skill.

## Permissions bloquantes

| Commande refusée | Impact |
|---|---|
| `bundle exec spring start 2>/dev/null &` | Spring background interdit → runs sans Spring |
| `COVERAGE=true bundle exec rspec ...` | Coverage non mesuré |
| `NO_COVERAGE=true bundle exec rspec ...` | Warm-up sans coverage refusé aussi |

## Actions

- [ ] Ajouter un pre-scan dans le scanner `TestOptimization` : ignorer les fichiers avec < 50 lignes ou < 3 examples (estimation : coût > bénéfice)
- [ ] Autoriser les permissions `spring start`, `COVERAGE=true rspec`, `NO_COVERAGE=true rspec` dans les settings du repo cible pour éviter ces refus
- [ ] Documenter dans le skill SKILL.md que `fixture_file_upload` + `let_it_be` sont incompatibles (IO stream consumé)
- [ ] Voir aussi [[2026-06-24-procedure-attestation-template-spec-ok.md]] — pattern de succès similaire sur spec avec let_it_be, mais gain significatif car plus d'examples
