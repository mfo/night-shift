---
agent-id: dossier-spec
spec-file: spec/models/dossier_spec.rb
status: succes
skill: test-optimization
date: 2026-03-15
---

# Kaizen — dossier_spec.rb let_it_be

## Métriques

- **Temps avant :** 64.03s (médiane 3 runs)
- **Temps après :** 54.79s (médiane 3 runs)
- **Gain :** 14.4%
- **Coverage avant :** 83.38%
- **Coverage après :** 83.38% (identique)

## Technique(s) appliquée(s)

- [x] T08 — let_it_be / before_all : 7 blocs convertis
  - `by_statut` (l.42-77) : 4 examples, 8 let → let_it_be
  - `brouillon_close_to_expiration` (l.167-215) : 3 examples, 6 let!/let → let_it_be
  - `en_construction_close_to_expiration` (l.217-276) : 4 examples, 6 let!/let → let_it_be
  - `termine_close_to_expiration` (l.278-338) : 4 examples, 6 let!/let → let_it_be
  - `avis_for` (l.567-647) : 8 examples, 7 let! → let_it_be (réordonné pour respecter les FK)
  - `with_notifiable_procedure` (l.2446-2471) : 2 examples, 8 let/let! → let_it_be
  - `never_touched_brouillon_expired` (l.2864-2893) : 3 examples, 4 let! → let_it_be

## Technique(s) tentées sans succès

- **Technique :** T09 — aggregate_failures (bloc degraded mode, l.1880-1898)
  **Raison :** Fusion de 3 `it` en 1 avec `aggregate_failures`. Mesure : 56.25s vs 54.79s baseline — dans le bruit, aucun gain significatif. Rollback.

- **Technique :** let_it_be avec `reload: true` / `refind: true`
  **Raison :** Les modifiers ne sont pas disponibles. `let_it_be` est require dans `spec_helper.rb:25` AVANT le chargement de Rails/ActiveRecord. Les modifiers ne s'enregistrent que si `ActiveRecord::Base` est déjà défini. Tentative de déplacer le require dans `rails_helper.rb` → FK violation sur les fixtures. Rollback.

- **Technique :** T08 sur d'autres blocs avec mutation
  **Raison :** Beaucoup de describe dans dossier_spec mutent les objets (`accepter!`, `passer_en_instruction!`, `update`, etc.). Sans `refind: true`, ces blocs ne peuvent pas utiliser `let_it_be` car l'état muté polluerait les tests suivants.

## Piège(s) rencontré(s)

- **Piège :** `let_it_be` modifiers (`reload:`, `refind:`) indisponibles
  **Cause :** `spec_helper.rb` charge `test_prof/recipes/rspec/let_it_be` avant Rails. Les modifiers s'enregistrent via un hook qui détecte `ActiveRecord::Base`, absent à ce stade.
  **Fix potentiel :** Ajouter `require 'test_prof/recipes/rspec/let_it_be'` dans `rails_helper.rb` (après le require de Rails) ET le retirer de `spec_helper.rb`. Mais cela casse les fixtures (FK violation). À investiguer plus en profondeur.

- **Piège :** Ordre des `let_it_be` dans `avis_for`
  **Cause :** `experts_procedure` dépend de `expert_1` et `expert_2` (FK). Avec `let!` l'ordre déclaratif n'importait pas (lazy evaluation + eager). Avec `let_it_be`, l'ordre d'insertion compte.
  **Fix :** Réordonner pour déclarer `expert_1`/`expert_2` avant `experts_procedure`.

- **Piège :** DB cassée après tentative de schema:load
  **Cause :** PostGIS extension échoue car libxml2 n'est pas linkée sur cette machine. `db:schema:load` crée les extensions avant les tables → échec → DB vide.
  **Fix :** Ne pas toucher à la DB. Restaurer via pg_dump depuis la DB principale (hors scope agent).

## Blocages

- **DB cassée** : La DB du worktree (`tps_test_poc_1_perf`) est vide (0 tables) suite à un `db:drop db:create db:schema:load` échoué (PostGIS/libxml2). Impossible de continuer les mesures sans restaurer la DB.
- **Modifiers let_it_be** : Sans `reload:`/`refind:`, le potentiel de T08 est limité aux blocs qui ne mutent pas leurs objets. C'est ~30% des blocs de dossier_spec. Le reste (state transitions, callbacks, etc.) ne peut pas être converti.

## Ce qu'on a appris

- `let_it_be` sans modifiers est déjà efficace sur les blocs read-only (scopes, queries, pure methods). 7 blocs convertis = -14.4%.
- dossier_spec.rb est dominé par des tests de state transitions qui mutent les objets. Pour aller plus loin, il faut soit activer les modifiers, soit utiliser `factory_default` (T11) pour réduire les cascades.
- La factory `:dossier` est très lourde (~15-25 INSERTs). Chaque `create(:dossier)` recrée une procedure complète. `factory_default` ou un trait `:minimal` (G05) aurait un impact majeur.
- Le fichier fait 2912 lignes / 231 examples — un candidat idéal pour un split en fichiers thématiques (scopes, state transitions, expiration, etc.).

## Actions suggérées pour la synthèse

- [ ] Investiguer le fix pour activer les modifiers `let_it_be` (déplacer le require + résoudre le conflit fixtures) → `spec_helper.rb` / `rails_helper.rb`
- [ ] Appliquer `factory_default` (T11) sur les describe à N dossiers pour la même procedure → `spec/models/dossier_spec.rb`
- [ ] Créer un trait `:minimal` sur la factory procedure (G05) → `spec/factories/procedure.rb`
- [ ] Restaurer la DB du worktree `tps_test_poc_1_perf` → `pg_dump` depuis `tps_test`
- [ ] Envisager un split de dossier_spec.rb en fichiers thématiques pour faciliter les futures optimisations
