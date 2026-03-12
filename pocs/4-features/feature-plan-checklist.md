# Checklist : Create Feature Plan (Phase 1)

**Version :** 2.0
**Temps estimé :** 1-2h
**Slash command :** `/feature-plan`

---

## 🎯 Vue d'Ensemble Phase 1

**Objectif :** Transformer spec validée en plan d'implémentation exécutable avec commits atomiques

**Input :** `specs/YYYY-MM-DD-[nom]-spec.md` (validé Phase 0)

**Output :** `specs/YYYY-MM-DD-[nom]-implementation-plan.md` (COMMIT_PLAN.md)

**Score autonomie cible :** 8/10

---

## ✅ Checklist Lecture Spec (20-30min)

- [ ] Spec complète lue attentivement
- [ ] Composants impactés listés
  - Models
  - Controllers
  - Jobs
  - Services/Queries
  - Views/Components
  - Tests

- [ ] Dépendances entre changements identifiées
  - DB doit être prêt avant code
  - Infrastructure avant features
  - Features avant UI
  - Tests après features

- [ ] Breaking changes repérés
  - Job signature changes
  - API changes
  - Service method changes

**Checkpoint :**
- Spec comprise dans son intégralité ?
- Ordre logique identifié ?

---

## 🔨 Checklist Découpage Commits (1h)

### Principes CRITIQUES Appliqués

- [ ] **1 commit = 1 concept isolé et testable**
- [ ] **Max 5 fichiers par commit** (idéal : 1-3)
- [ ] **Max 20 commits total**
  - Si > 20 → revoir découpage ou fusionner commits similaires
- [ ] **Ordre logique respecté**
  - DB → Infrastructure → Features → UI → Tests → Cleanup → UX

### 7 Phases Standards Définies

- [ ] **Phase 1: Database** (migrations, backfill, constraints)
  - Add column nullable
  - Backfill data (MaintenanceTask)
  - Add constraints (NOT NULL, UNIQUE)

- [ ] **Phase 2: Infrastructure** (models, validations, query objects)
  - Add validations
  - Create Query Object (si DRY)
  - Update factory

- [ ] **Phase 3: Features** (routes, controllers, jobs)
  - Add routes
  - Add controller actions
  - Update job signature (BREAKING si applicable)

- [ ] **Phase 4: UI** (components, views)
  - Update components
  - Update views
  - Update links

- [ ] **Phase 5: Tests** (system, unit)
  - Update system specs
  - Update unit specs (controller, component, model)

- [ ] **Phase 6: Cleanup** (suppression code mort)
  - Remove legacy service
  - Remove old routes
  - Remove dead code

- [ ] **Phase 7: UX** (optionnel - améliorations cosmétiques)
  - Wording
  - Typographie
  - A11y improvements

### Patterns Critiques Appliqués

- [ ] **Pattern : Migration DB Safe (3 commits)**
  ```
  Commit 1: db: add column (nullable)
  Commit 2: maintenance: backfill data
  Commit 3: db: add constraints (NOT NULL, UNIQUE)
  ```

- [ ] **Pattern : Breaking Change Bloc**
  ```
  Commit N: job: change signature (BREAKING)
  Commit N+1: fix call-site 1
  Commit N+2: fix call-site 2
  ```
  - Documentation : "Merge commits N-X en bloc"
  - Commit message avec `⚠️ TESTS BROKEN` + plage fix

- [ ] **Pattern : Tests Séparés**
  ```
  Commit N-1: tests: update system specs
  Commit N: tests: update unit specs
  ```

- [ ] **Pattern : Tests Verts à Chaque Commit**
  - Chaque commit DOIT avoir tests passants
  - Exception : Breaking change documenté

**Checkpoint :**
- Commits atomiques définis ?
- Max 20 commits respecté ?
- Phases logiques respectées ?
- Breaking changes isolés en blocs ?

---

## 📝 Checklist Documentation Commits (20-30min)

**Pour CHAQUE commit, documenter avec template :**

- [ ] **Objectif** : 1 phrase explicite
- [ ] **Fichiers à modifier** : Liste précise avec (create/edit/delete)
- [ ] **Actions** : Code exact ou instructions précises
- [ ] **Tests à exécuter** : Commandes rspec
- [ ] **Notes** : Warnings, breaking changes, Strong Migrations

### Template Commit Standard

```markdown
### ✅ Commit X: `scope: one-line description`

**Objectif :** [1 phrase explicite]

**Fichiers à modifier :**
- [ ] `path/to/file.rb` (create/edit)
- [ ] `path/to/spec.rb` (create/edit)

**Actions :**
[Code exact ou instructions]

**Tests à exécuter :**
```bash
bundle exec rspec path/spec.rb
```

**Notes :**
- ⚠️ BREAKING CHANGE si applicable
- ⏱️ Estimation : X min
```

### Commits Spéciaux Documentés

- [ ] **Migration DB** : Strong Migrations notes
  ```ruby
  # Si table > 1M rows
  disable_ddl_transaction!
  algorithm: :concurrently
  ```

- [ ] **Breaking Change** : Commit message complet
  ```
  job: update JobName signature (BREAKING)

  BREAKING CHANGE: Add tunnel_id parameter

  Call-sites to update:
  - [ ] app/jobs/cron/...
  - [ ] app/controllers/...
  - [ ] spec/jobs/...

  ⚠️ Tests broken until commits X-Y fix all call-sites
  Merge commits X-Y en bloc
  ```

- [ ] **Backfill** : Idempotence vérifiée
  ```ruby
  # Task peut être relancée sans problème
  def collection
    Model.where(field: nil)
  end
  ```

**Checkpoint :**
- Tous commits documentés ?
- Template respecté ?
- Estimations temps raisonnables ?

---

## 📊 Checklist Tableau Récapitulatif

- [ ] **Tableau créé avec colonnes :**
  - # (numéro commit)
  - Phase
  - Titre
  - Breaking (Oui/Non)
  - Fichiers (nombre estimé)
  - Temps estimé

- [ ] **Statistiques calculées :**
  - Commits total : N (< 20)
  - Phases : 7 (ou moins si phase 7 optionnelle)
  - Fichiers impactés : ~X
  - Breaking changes : N (commits X-Y)
  - Temps estimé total : X-Yh

**Exemple tableau :**
```markdown
| # | Phase | Titre | Breaking | Fichiers | Temps |
|---|-------|-------|----------|----------|-------|
| 1 | DB | add column | Non | 1 migration | 15min |
| 2 | DB | backfill data | Non | 1 task | 30min |
| ... | ... | ... | ... | ... | ... |
```

**Checkpoint :**
- Tableau complet ?
- Breaking changes clairement identifiés ?
- Estimation totale réaliste (8-20h) ?

---

## 👤 Checklist Validation User (10min)

- [ ] Nombre total commits présenté (< 20)
- [ ] Phases identifiées (7 phases standards)
- [ ] Breaking changes (plage commits X-Y)
- [ ] Estimation temps totale (commits × 30-60min)
- [ ] Tableau récapitulatif présenté

**Questions user :**
- Structure commits acceptable ?
- Breaking changes en bloc OK ?
- Estimation temps réaliste ?

**Checkpoint final Phase 1 :**
- [ ] User approuve structure du plan ?
- [ ] COMMIT_PLAN.md créé et validé ?
- [ ] Prêt pour Phase 2 (Implementation) ?

---

## ⚠️ Pièges Critiques à Éviter

### 1. Commits Trop Larges
**Symptôme :** Commit avec > 5 fichiers modifiés
**Solution :** Découper en commits plus petits (1 concept = 1 commit)

### 2. Tests Séparés du Code
**Symptôme :** Commits 4-14 code, commits 15-16 tests
**Solution :** Interleave code + specs à chaque commit

### 3. Breaking Changes Éparpillés
**Symptôme :** Change signature commit 5, fix call-site commit 12
**Solution :** Grouper en bloc (change + fix tous call-sites)

### 4. Ordre Illogique
**Symptôme :** UI avant DB, tests avant features
**Solution :** Respecter ordre dépendances (DB → Infra → Features → UI → Tests)

### 5. > 20 Commits
**Symptôme :** Plan avec 25+ commits
**Solution :** Fusionner commits similaires ou revoir découpage feature

---

## 🔧 Commandes Utiles

### Estimer Nombre Fichiers Impactés
```bash
# Liens à mettre à jour
grep -r "old_route_name" app/views/ app/components/

# Call-sites job/service
grep -r "JobName.perform" app/ lib/ spec/

# Tests à modifier
find spec -name "*nom*_spec.rb"
```

### Vérifier Ordre Dépendances
```bash
# Vérifier qu'aucun fichier n'utilise code pas encore créé
grep -r "NewQueryName" app/
# Si résultats avant commit création Query → ordre incorrect
```

---

## 📊 Métriques de Succès

**Phase 1 réussie si :**
- [ ] Commits atomiques (< 20)
- [ ] Phases logiques (7 phases)
- [ ] Breaking changes isolés (blocs documentés)
- [ ] Tests exécutables après chaque commit
- [ ] User a validé structure
- [ ] Estimation temps réaliste (8-20h)

**Temps total Phase 1 :** 1-2h
- Lecture spec : 20-30min
- Découpage commits : 1h
- Documentation : 20-30min
- Validation user : 10min

**Score autonomie :** 8/10

---

## 🔗 Références

**Template :** `feature-plan-template.md`
**Input :** Spec validée Phase 0
**Patterns :** `feature-implementation-patterns.md`
**Methodology :** `setup.md`
**Prochaine phase :** `feature-implementation-checklist.md`

---

**Version :** 2.0
**Source :** Sessions 1-6 kaizen (Simpliscore tunnel_id)
**Status :** Production-ready

