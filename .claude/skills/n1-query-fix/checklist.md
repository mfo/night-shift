# Checklist n1-query-fix

## Triage (gate)
- [ ] Specs lancees avec Prosopite actif
- [ ] Chaque N+1 classifie : PROD (call stack dans app/) ou TEST (call stack dans spec/)
- [ ] Au moins 1 N+1 PROD identifie — sinon SKIP (ecrire pr-description.md "Skip" et terminer)

## Analyse (PROD uniquement)
- [ ] Fichier cible lu et compris (model/concern)
- [ ] `.skill-context.json` lu (si present)
- [ ] Patterns N+1 PROD identifies (table, association, call sites dans app/)
- [ ] Strategie de fix choisie par pattern (includes/preload/batch/cache)

## Fix
- [ ] Seul du code applicatif modifie (app/, config/) — PAS de modifs spec/ pour faire taire Prosopite
- [ ] Eager loading ajoute au bon endroit (scope/controller, pas default_scope)
- [ ] Pas de surcharge inutile (includes cible, pas global)
- [ ] GraphQL : batch loader si applicable

## Validation
- [ ] Tests passes (rspec) — les N+1 TEST peuvent encore echouer, c'est OK
- [ ] Rubocop OK sur fichiers modifies

## Livrable
- [ ] 1+ commits propres avec message `perf(<scope>): ...`
- [ ] Seuls des fichiers app/ et config/ dans le commit
- [ ] `pr-description.md` avec triage (N PROD / M TEST) et tableau des patterns PROD fixes
