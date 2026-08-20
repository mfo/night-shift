---
name: 2026-08-19-graphql-spec-failed
description: Flaky-test-fix failed on graphql_spec.rb — context overflow after 5 permission denials
metadata:
  type: kaizen
---

# Flaky-test-fix failed: graphql_spec.rb

**Ce qui s'est passé :**
Session autolearn lancée sur `spec/lib/tasks/graphql_spec.rb` (12 lines, 1 example — GraphQL schema comparison). L'agent a lu le fichier, puis a tenté de run le spec 5× avec seeds aléatoires pour détecter la flakiness.

**Bien passé :**
- L'agent a correctement identifié le fichier et son seul test (vérifie que `schema.graphql` est synchronisé avec le schema GraphQL).
- A exploré les workflows CI (rails_schema_check.yml, ci.yml) pour comprendre le contexte.

**Mal passé :**
- **5 commandes Bash refusées** pour "Contains simple_expansion" à cause de `$((RANDOM % 65536))` — le shell arithmetic expansion est détecté comme motif dangereux.
- L'agent a réessayé 3 fois avec des variations (5 runs → 3 runs, avec/sans grep) au lieu de changer d'approche (écrire un script, utiliser des seeds fixes).
- Après les refus, a continué à lire des workflows CI, remplissant le contexte.
- **Context overflow** à 100738 tokens (limite 100000 deepseek-v4-flash) → API Error 400, session terminée.
- 42 turns, $2.47, 0 fix produit.

**Appris :**
- `$RANDOM` et `$((...))` dans les commandes Bash déclenchent "simple_expansion" — le hook les refuse. L'agent doit soit écrire un script shell dans un fichier d'abord, soit utiliser des seeds littéraux (ex: `--seed 1 --seed 2 --seed 3`).
- Le spec graphql_spec.rb est court (12 lines, 1 example) et ne semble pas flaky — c'est un test de comparaison de schema. Le fix aurait probablement été de le `skip` ou d'ajouter retry_on_failure, mais la session n'a jamais atteint cette phase.
- Le modèle deepseek-v4-flash avec 100k context est saturé après ~42 turns d'erreurs et de lecture de fichiers inutiles.

**Permissions bloquantes :**
5 Bash calls refusées (même cause racine — `$RANDOM`):
1. `for i in 1 2 3 4 5; do bundle exec rspec ... --seed $((RANDOM % 65536)) ...`
2. Variante avec `grep -E`
3. Variante avec 3 runs
4. `verify-flaky.sh spec/lib/tasks/graphql_spec.rb:7` (via script skill)
5. Même commande avec timeout 600s

**Actions :**
1. Modifier le prompt du skill flaky-test-fix pour interdire `$RANDOM` / `$((...))` — utiliser des seeds littéraux ou un script fichier.
2. Ajouter un early-exit dans le Runner : si le fichier spec fait < 20 lines, le fix flaky n'est pas rentable — `skip` directement.
3. Dans le flaky-test-fix skill, remplacer le detect-loop par `bundle exec rspec ... --seed 1,2,3,4,5` séquentiel sans shell expansion.
4. Pour le backlog item actuel, le marquer comme `skipped` (failure_reason: ContextLimit) — le spec n'est pas flaky, le fix serait un skip ou retry_on_failure trivial.
