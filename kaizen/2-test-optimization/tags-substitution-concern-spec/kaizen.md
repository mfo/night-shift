---
agent-id: tags-substitution-concern-spec
spec-file: spec/models/concerns/tags_substitution_concern_spec.rb
status: succes
skill: test-optimization
date: 2026-03-16
---

# Kaizen — tags_substitution_concern_spec.rb

## Métriques

- **Temps avant :** 15.97s (médiane 3 runs)
- **Temps après :** 10.79s (médiane 3 runs)
- **Gain :** 32.4% (5.18s)
- **Coverage avant :** N/A (pas de baseline dans l'inventaire)
- **Coverage après :** 52.4%
- **Examples :** 52 → 41

## Technique(s) appliquée(s)

- [x] T04 : réduire setup inutile — suppression de `instructeur` non utilisé dans `tags_substitutions`, déplacement vers le contexte `date tag` où il est réellement nécessaire
- [x] T04 : réduire setup inutile — `etablissement` mis à nil par défaut dans `replace_tags`, créé uniquement dans les contextes nécessitant des transitions d'état (accepter!, passer_en_construction!)
- [x] T04 : réduire setup inutile — réutilisation de la procedure partagée dans les contextes "motivation" et "not termine" (évite création de procedures supplémentaires)
- [x] T10 : let! → let — conversion du `dossier` eager en lazy dans `replace_tags` (évite la création de dossiers quand le contexte override le let)
- [x] T09 : aggregate_failures — fusion de 4 `it` date tags en 1 (économise 3× le setup coûteux : 4 transitions d'état)
- [x] T09 : aggregate_failures — fusion de 3 contexts `tags` (accepte/instruction/construction) en 1 `it` avec helper `tags_for`
- [x] T09 : aggregate_failures — fusion de `used_tags_for` et `used_type_de_champ_tags` en 1 describe+it
- [x] T09 : aggregate_failures — fusion de 4 `it` spaces normalization (shared_example × 2 templates) en 1
- [x] T09 : aggregate_failures — fusion de 2 `it` revisions (original/revised label) en 1

## Technique(s) tentées sans succès

- **Technique :** T08 let_it_be pour `service` (avec et sans `administrateur` partagé)
  **Raison :** FK violation — `check_all_foreign_keys_valid!` de Rails 7.2 détecte l'orphelin. Le `administrateur_id` du service persiste après rollback de la transaction par-test, mais l'administrateur est nettoyé. Même en créant l'administrateur en `let_it_be`, le mécanisme de vérification FK de Rails échoue. Confirmé : le piège connu `let_it_be` sur ce projet s'étend au-delà des modifiers — c'est le mécanisme de FK validation qui pose problème.

## Piège(s) rencontré(s)

- **Piège :** `etablissement` nécessaire pour les transitions d'état (accepter!, passer_en_construction!)
  **Cause :** `DossierOperationLog.serialize_subject` appelle `SerializerService.dossier` qui accède à `etablissement` lors de la sérialisation du log d'opération
  **Fix :** Ajouter `let(:etablissement) { create(:etablissement) }` dans les contextes qui font des transitions d'état

- **Piège :** `let_it_be` + FK validation Rails 7.2
  **Cause :** `ActiveRecord::FixtureSet.check_all_foreign_keys_valid!` valide TOUTES les FK de la DB après chaque insertion de fixtures, pas seulement les nouvelles
  **Fix :** Pas de fix simple — `let_it_be` n'est pas utilisable pour les objets avec des FK vers d'autres tables sur ce projet

## Blocages

- `let_it_be` inutilisable (modifiers ET FK validation) — le levier principal du catalogue est bloqué sur ce projet
- Beaucoup de contextes overrident `types_de_champ_public`, ce qui force une nouvelle procedure à chaque fois — impossible de partager la procedure entre ces contextes

## Ce qu'on a appris

- Le plus gros gain vient de la fusion T09 des date tags (4→1) : le setup de transitions d'état (brouillon→construction→instruction→accepte) est très coûteux (~1s par exécution)
- Les tests "légers" (tags, used_tags_for, parser) sont déjà rapides (<0.3s chacun) — les fusionner apporte peu de gain absolu
- `etablissement` est un side-effect caché : pas directement utilisé par les tests mais requis par le serializer lors des transitions d'état
- La validation FK de Rails 7.2 (`check_all_foreign_keys_valid!`) est un obstacle fondamental à `let_it_be` sur ce projet — ce n'est pas juste un problème de modifiers

## Actions suggérées pour la synthèse

- [ ] Investiguer un moyen de désactiver `check_all_foreign_keys_valid!` dans le contexte `let_it_be` / `before_all` — ça débloquerait le levier #1 du catalogue
- [ ] Documenter dans patterns.md que T09 aggregate_failures est très efficace quand le `before` fait des transitions d'état dossier (gain ~1s par `it` économisé)
- [ ] Ajouter le piège `etablissement` requis par `DossierOperationLog` dans les pièges connus du skill
