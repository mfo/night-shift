---
status: traité
date_synth: 2026-08-20
status: traité
date_synth: 2026-08-20
---

# Kaizen — flaky-test-fix échoué sur dossier_rebase_concern_spec.rb

## Ce qui s'est passé

Le skill `flaky-test-fix` a été lancé sur `spec/models/concerns/dossier_rebase_concern_spec.rb` dans un worktree dédié (`auto-flaky-test-fix-m-c-dossier_rebase_concern`). Le test flaky identifié est `"updates the brouillon champs with the latest revision changes"` (ligne 187), avec 3 échecs en merge queue et 0 retry réussi.

Le skill a investigué pendant 30 tours : lecture du spec (567 lignes), lecture du concern `DossierRebaseConcern`, analyse du `TestAdapter` ActiveJob, exploration du mécanisme `perform_enqueued_jobs`. Puis planté sur une erreur API 400 : dépassement de contexte.

## Bien passé

- Le scanner a correctement identifié le fichier et le test flaky (3 merge queue failures, line 187)
- Le worktree a été créé proprement
- L'investigation a été approfondie : lecture du concern, analyse du `TestAdapter`, compréhension du flux `publish_revision! → perform_enqueued_jobs`

## Mal passé

- **Contexte overflow** : `100356 > 100000 tokens` sur deepseek-v4-flash. C'est la 3ème occurrence de ce pattern (après `dossier_spec.rb` le 2026-06-17 et `procedure_clone_concern.rb` le 2026-07-08). Le spec fait 567 lignes avec un setup complexe (types_de_champ imbriqués, révisions multiples, jobs async), et la lecture du concern + TestAdapter gonflé le contexte au-delà de la limite.
- **$1.70 gaspillé** : 30 tours d'investigation pour une erreur de contexte évitable.
- **2 permissions refusées** : `ruby -e Gem::Specification.find_by_name('rails').version` et `activejob.gem_dir` — l'utilisateur a refusé. Cela a forcé le skill à explorer par chemins alternatifs, consommant des tours supplémentaires.

## Appris

1. Les specs avec setup complexe (567+ lignes, révisions, jobs async) sont systématiquement à risque sur deepseek-v4-flash (100k limit). Le seuil de danger est ~100k tokens de prompt.
2. Les permissions refusées sur des commandes Ruby gem forcing l'exploration de chemins alternatifs ajoute ~5-10 tours de contexte.
3. Le pattern d'échec est identique aux précédents kaizen : contexte overflow, pas un bug du skill.

## Permissions bloquantes

- `ruby -e "puts Gem::Specification.find_by_name('rails').version"` — refusé
- `ruby -e "puts Gem::Specification.find_by_name('activejob').gem_dir"` — refusé

Ces deux commandes sont bénignes (lecture de version/chemin gem) et devraient être autorisées en permanence pour ce skill.

## Actions

1. **Autoriser les deux commandes Ruby gem** dans `settings.json` du projet cible (ou en global) pour éviter les tours de détour coûteux.
2. **Ajouter un guard dans le skill `flaky-test-fix`** : avant de lancer l'investigation, estimer la taille du contexte (spec + concern + dépendances). Si > 90k tokens estimés sur deepseek-v4-flash, soit (a) limiter la profondeur d'investigation, soit (b) reporter sur un modèle avec plus de contexte.
3. **Limiter la lecture des dépendances amont** : lire le concern/implementation sans lire les internals du framework (ActiveJob TestAdapter). Le flaky est dans le spec, pas dans Rails — creuser le framework ajoute du contexte sans valeur ajoutée.
4. **Vérifier si `flaky-test-fix` peut détecter `dossier_rebase_concern` comme trop gros** et skip automatiquement avec une raison claire (`ContextLimit` verdict).
