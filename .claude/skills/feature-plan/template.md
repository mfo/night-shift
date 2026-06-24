# COMMIT_PLAN : [Titre Feature]

**Date :** YYYY-MM-DD
**Basé sur spec :** `specs/YYYY-MM-DD-[nom]-spec.md`
**Issue Source :** [URL issue GitHub — reprendre de la spec, ou N/A]
**Créé par :** Agent Claude
**Validé par :** [User]
**Status :** Draft v1 | Validated

---

## Principes

1. **Tests verts à chaque commit** — exception : breaking change documenté avec `TESTS BROKEN` + plage fix
2. **1 commit = 1 concept** — max 5 fichiers/commit (idéal 1-3), max 20 commits total
3. **Ordre logique (7 phases)** : DB → Infrastructure → Features → UI → Tests → Cleanup → UX
4. **Breaking changes en blocs** : change signature → fix call-sites → merge en bloc

---

## Vue d'Ensemble

| Métrique | Valeur |
|----------|--------|
| **Commits total** | N (< 20) |
| **Phases** | 7 |
| **Fichiers impactés** | ~X |
| **Breaking changes** | N (commits X-Y) |

### Tableau Récapitulatif

| # | Phase | Titre | Breaking | Fichiers |
|---|-------|-------|----------|----------|
| 1 | DB | ... | Non | 1 |
| ... | ... | ... | ... | ... |

**Commits breaking :** X-Y (merge en bloc)

---

## Phase 1 : Database

**Objectif :** Préparer fondations DB

### Pattern : Migration DB Safe (3 commits)

```
Commit 1: db: add column (nullable, pas de constraint)
Commit 2: maintenance: backfill data (MaintenanceTask idempotente)
Commit 3: db: add constraints (NOT NULL, UNIQUE — après backfill)
```

**Strong Migrations :** si table > 1M rows → `disable_ddl_transaction!` + `algorithm: :concurrently`

---

## Phase 2 : Infrastructure

**Objectif :** Validations model + Query Object DRY + Factory updates

- Validations Rails (vérifier cohérence scope ↔ index DB)
- Query Object (si logique répétée 3+)
- Factory update (champ requis)

---

## Phase 3 : Features

**Objectif :** Routes + Controller + Jobs

### Pattern : Breaking Change Bloc

```
Commit N:   job: change signature (BREAKING) — commit message avec TESTS BROKEN
Commit N+1: fix call-site 1
Commit N+2: fix call-site 2
→ Merge en bloc obligatoire
```

**Trouver call-sites :** `grep -r "JobName.perform" app/ lib/ spec/`

---

## Phase 4 : UI

**Objectif :** Mise à jour components + views

- Components : nouvelles props, liens mis à jour
- Views : liens et formulaires avec nouveaux params
- A11y : ARIA labels sur formulaires, focus management, heading hierarchy, contrastes RGAA
- Détection fichiers : `grep -r "old_route_name" app/views/ app/components/`

---

## Phase 5 : Tests

**Objectif :** Tests système + unitaires

- System specs (workflow E2E)
- Unit specs (controller, component, model)
- **Pattern isolation :** setup contexte pour before_actions dans les tests controller

---

## Phase 6 : Cleanup

**Objectif :** Suppression code mort

```bash
grep -r "OldClassName" app/ lib/ spec/
# Si aucun résultat → safe to delete
```

---

## Phase 7 : UX (optionnel)

**Objectif :** Améliorations cosmétiques — wording, typographie, a11y

Découple technique (phases 1-6) et cosmétique (phase 7) pour faciliter la review.

---

## Rollout Plan (si applicable)

_Remplir si la spec a coché au moins un item en Section 15. Supprimer sinon._

| Étape | Action | Rollback |
|-------|--------|----------|
| 1 | [deploy migration] | [rollback migration] |
| 2 | [enable flag %] | [disable flag] |
| 3 | [remove flag + dead code] | — |

**Feature flag lifecycle :** create → enable (% progressif) → monitor → remove

---

## Template Commit

Chaque commit suit ce format :

```markdown
### Commit X: `scope: one-line description`

**Objectif :** [1 phrase]

**Fichiers à modifier :**
- [ ] `path/to/file.rb` (create/edit/delete)

**Actions :**
[Code ou instructions]

**Tests à exécuter :**
```bash
bundle exec rspec path/spec.rb
```

**Notes :**
- Breaking change / Strong Migration si applicable
```

---

## Validation Checklist

**Avant implémentation :**
- [ ] User a validé ce plan ?
- [ ] Breaking changes compris ?
- [ ] Tests verts à chaque commit = principe accepté ?

**Après implémentation :**
- [ ] Suite complète tests passe (0 failures) ?
- [ ] Rubocop clean (0 offenses) ?
- [ ] Prêt pour review (Stage 3) ?

---

## Références

**Spec source :** `specs/YYYY-MM-DD-[nom]-spec.md`
**Patterns :** `../feature-implementation/patterns.md`
