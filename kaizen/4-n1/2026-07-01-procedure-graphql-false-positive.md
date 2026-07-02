# n1-query-fix: faux positif GraphQL batch loader (PR #13391)

**Date**: 2026-07-01
**Skill**: n1-query-fix
**Item**: app/models/procedure.rb
**Verdict**: faux positif — PR à reverter

## Ce qui s'est passé

Le skill a détecté un N+1 sur `active_storage_attachments` pour `Procedure` (logo, notice, deliberation) via le cross-report Prosopite x Skylight. Il a ajouté des `with_attached_*` preloads dans deux scopes :

1. `demarches_publiques` (query_type.rb) — scope GraphQL
2. `for_api_v2` (procedure.rb) — scope API v2

## Pourquoi c'est un faux positif

- **`demarches_publiques`** : le N+1 est déjà résolu par `Loaders::Association` (GraphQL::Batch::Loader) qui batch les associations à la demande. Le preload `with_attached_*` charge systématiquement les attachements même quand le client GraphQL ne les demande pas.

- **`for_api_v2`** : utilisé par `demarche(number:)` qui retourne un `DemarcheType`. Or `DemarcheType` n'expose pas `logo`, `notice`, ni `deliberation`. Les preloads chargent des données jamais consommées.

## Root cause

Le scanner n1-query-fix se base sur les patterns Prosopite (tests) croisés avec Skylight (prod). Prosopite détecte le N+1 dans les tests où le batch loader GraphQL n'est pas actif (les tests n'exécutent pas les queries via le framework GraphQL complet). Le signal est donc un artefact du contexte de test, pas un vrai N+1 prod.

## Learnings

1. **Les N+1 GraphQL avec batch loaders sont des faux positifs Prosopite** — Prosopite voit le pattern SQL mais pas la résolution par le batch loader
2. **Le skill devrait vérifier si un batch loader/dataloader existe** avant de proposer un preload eager
3. **Les scopes `for_api_v2` doivent être vérifiés** : quels types GraphQL les consomment et quels champs sont exposés

## Action

- [ ] Ajouter dans le skill SKILL.md ou patterns.md : "Vérifier si un GraphQL::Batch::Loader ou dataloader résout déjà le N+1 avant de proposer un preload"
- [ ] Considérer un filtre dans le scanner : exclure les patterns dont la call stack passe par un loader GraphQL
