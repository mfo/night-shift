# Checklist : Create Feature Spec (Phase 0)

**Version :** 2.0
**Temps estimé :** 4-8h
**Slash command :** `/feature-spec`

---

## 🎯 Vue d'Ensemble Phase 0

**Objectif :** Créer une spécification technique complète et validée

**Livrables attendus :**
- `specs/YYYY-MM-DD-[nom]-spec.md` (spec finale)
- `specs/YYYY-MM-DD-[nom]-review-v1.md` (review PM)
- `specs/YYYY-MM-DD-[nom]-review-v2.md` (validation finale)

**Score autonomie cible (cible) :** 7/10 seul, 9/10 avec review PM

---

## ✅ Checklist Pré-Démarrage

**Avant de commencer à rédiger spec :**

- [ ] **Bug architectural détecté ?**
  - Si oui → STOP patch, faire spec globale
  - Si non → Continuer

- [ ] **> 5 fichiers impactés estimés ?**
  - Si oui → Spec obligatoire
  - Si non → Considérer implémentation directe

- [ ] **Décisions d'architecture nécessaires ?**
  - Lister questions pour user
  - Format identifiants, trade-offs perf, breaking changes, etc.

- [ ] **Logique répétée 3+ fois identifiée ?**
  - Proposer Query Object proactif

---

## 📝 Checklist Analyse Problème (30min)

- [ ] Code existant lu (fichiers impactés)
- [ ] Architecture actuelle comprise
- [ ] Root cause identifiée (si bug)
- [ ] Grep call-sites effectué (si breaking change potentiel)
  ```bash
  grep -r "ClassName\|method_name" app/ lib/ spec/
  ```
- [ ] Tests existants identifiés
  ```bash
  find spec -name "*nom_fichier*_spec.rb"
  ```

**Checkpoint :**
- Problème compris clairement ?
- Si NON → Demander clarifications au user

---

## 🏗️ Checklist Conception Architecture (1-2h)

### Questions Métier à Poser au User

- [ ] Format des identifiants ? (UUID, hex, int)
- [ ] Trade-off performance vs. simplicité ?
- [ ] Breaking changes acceptables ?
- [ ] Auto-lancement ou contrôle user ?
- [ ] Validation stricte ou permissive ?

### Patterns à Détecter Proactivement

- [ ] **Logique répétée 3+ fois** → Query Object proposé ?
  ```bash
  grep -r "pattern_métier" app/ | wc -l
  # Si >= 3 → Proposer extraction
  ```

- [ ] **N+1 queries identifiées** → Trade-off documenté ?
  - Contexte (volume data, fréquence)
  - Option optimisée vs. Option simple
  - Rationale choix

- [ ] **Breaking changes détectés** → Call-sites listés ?
  ```bash
  grep -r "JobName.perform" app/ lib/ spec/
  # Lister tous fichiers impactés
  ```

- [ ] **Index DB manquants** → Proposition ajout ?
  - Performance queries fréquentes
  - Unicité contraintes métier

- [ ] **Nesting > 2 niveaux** → Self-documenting variables proposé ?
  - Conditions imbriquées difficiles à lire
  - Variables auto-documentées + if/elsif/else unique

**Checkpoint :**
- Architecture conçue ?
- Décisions prises avec user ?

---

## 📄 Checklist Rédaction Spec v1 (1-2h)

### 15 Sections Obligatoires

- [ ] **1. Contexte & Problème**
  - Description problème
  - Root cause (si bug) avec preuve
  - Objectifs (checkboxes actionables)

- [ ] **2. Décisions d'Architecture**
  - Pour chaque décision : Choix + Alternative + Rationale + Impact
  - Patterns pré-approuvés appliqués (Query Object, Self-documenting, etc.)

- [ ] **3. Architecture Proposée**
  - Vue d'ensemble (diagramme ASCII ou description)
  - Composants impactés (Model, Controller, Jobs, Services, Views)

- [ ] **4. Modèle (Database & ActiveRecord)**
  - Migrations (Pattern Migration DB Safe si colonne obligatoire)
  - Validations
  - Index (vérifier cohérence avec validations uniqueness)

- [ ] **5. Controller**
  - Routes (nouvelles + modifications)
  - Actions (avec gestion nesting si complexe)

- [ ] **6. Jobs**
  - Signature (documenter BREAKING si changement)
  - Call-sites impactés (trouvés via grep)

- [ ] **7. Services / Query Objects**
  - Extraction DRY (si logique répétée 3+)
  - Rationale (testable, maintenable, extensible)

- [ ] **8. Tests**
  - Tests à créer (Model, Query, Controller, Component, System)
  - Tests à modifier (avec pattern isolation si before_action)
  - Principe : Tests verts à chaque commit

- [ ] **9. Migration de Données (Backfill)**
  - Strategy (MaintenanceTask idempotente)
  - Production data impact
  - Rollback plan

- [ ] **10. Breaking Changes**
  - Liste complète avec call-sites (trouvés via grep)
  - Plan migration (bloc commits N-X)
  - Commit message template

- [ ] **11. Performance**
  - N+1 queries identifiées
  - Trade-offs documentés avec rationale
  - Index à ajouter

- [ ] **12. Sécurité**
  - Validations (format, unicité, présence)
  - Authorization (qui peut créer/modifier/voir)

- [ ] **13. UX / Product**
  - Comportement attendu
  - Edge cases

- [ ] **14. Rollout Strategy**
  - Phases déploiement
  - Feature flags si applicable

- [ ] **15. Métriques & Monitoring**
  - Métriques à tracker
  - Alertes à configurer

**Checkpoint :**
- 15 sections complètes ?
- Breaking changes documentés ?
- Trade-offs justifiés ?

---

## 🔍 Checklist Review Agent PM (45min-1h)

**⚠️ OBLIGATOIRE pour specs > 500 lignes**

- [ ] Agent PM Senior lancé
- [ ] Review findings analysés (10-20 problèmes attendus)
- [ ] Problèmes **🔴 critiques** corrigés (tous, pas de compromis)
  - Index DB manquants
  - Breaking changes non documentés
  - Validations insuffisantes
  - Migration données unclear

- [ ] Problèmes **🟠 importants** corrigés (tous)
  - Tests non couverts
  - Trade-offs non justifiés
  - Sécurité (format, unicité, authz)
  - Edge cases manquants

- [ ] Problèmes **🟡 nice-to-have** triés (backlog ou fix)

### Focus Review PM

- [ ] Breaking changes documentés avec call-sites ?
- [ ] Index DB cohérents avec validations uniqueness ?
- [ ] Tests listés (créer + modifier) ?
- [ ] Migration données claire (backfill strategy) ?
- [ ] Trade-offs justifiés (rationale explicite) ?
- [ ] Sécurité validée (format, unicité, authz) ?
- [ ] Edge cases couverts ?

**Checkpoint :**
- Spec v2 validée ?

---

## 👤 Checklist User Review (1-2h)

- [ ] Spec v2 présentée au user
- [ ] Décisions d'architecture tranchées
  - Format identifiants
  - Trade-offs performance
  - Breaking changes
  - Auto-lancement vs. contrôle user

- [ ] Breaking changes acceptés
- [ ] Trade-offs validés
- [ ] Estimation temps réaliste (~8-20h implémentation)

**Itérations attendues :** Max 8 rounds

**Checkpoint final Phase 0 :**
- [ ] User approuve l'architecture ?
- [ ] Spec finale validée ?
- [ ] Prêt pour Phase 1 (Create-Plan) ?

---

## 🔧 Commandes Utiles

### Détection Call-Sites (Breaking Changes)
```bash
# Jobs
grep -r "JobName.perform" app/ lib/ spec/

# Méthodes
grep -r "method_name" app/ lib/ spec/

# Services
grep -r "ServiceName.new" app/ lib/ spec/
```

### Détection Duplications (Query Object)
```bash
# Chercher pattern répété
grep -r "pattern_métier" app/ | wc -l

# Trouver fichiers contenant pattern
grep -r "pattern_métier" app/
```

### Détection Tests Existants
```bash
# Tests pour fichier spécifique
find spec -name "*nom_fichier*_spec.rb"

# Tests par type
find spec/models -name "*.rb"
find spec/controllers -name "*.rb"
find spec/system -name "*.rb"
```

---

## ⚠️ Pièges Critiques à Éviter

### 1. Patch au lieu de Spec Globale
**Symptôme :** Bug architectural découvert → tentation de patcher
**Solution :** STOP et proposer spec globale

### 2. Validation Rails Sans Index DB
**Symptôme :** `validates :x, uniqueness: { scope: [...] }`
**Vérification obligatoire :**
```bash
grep -r "add_index.*unique: true" db/migrate/
cat db/schema.rb | grep -A3 "unique: true"
```
**Impact si raté :** Tests passent, prod crashe (PG::UniqueViolation)

### 3. Trade-Offs Non Documentés
**Symptôme :** N+1 query détectée mais pas de rationale
**Solution :** Documenter : Contexte + Options + Choix + Rationale

---

## 📊 Métriques de Succès

**Phase 0 réussie si :**
- [ ] 15 sections complètes
- [ ] Review agent PM effectuée (si > 500 lignes)
- [ ] User a approuvé architecture
- [ ] Estimation temps réaliste (8-20h)
- [ ] Score confiance ≥ 7/10

**Temps total Phase 0 :** 4-8h
- Analyse : 30min
- Conception : 1-2h
- Rédaction v1 : 1-2h
- Review PM : 45min-1h
- Itérations user : 1-2h

---

## 🔗 Références

**Template :** `template.md` (dans ce dossier)
**Patterns :** `../feature-implementation/patterns.md`
**Prochaine phase :** `../feature-plan/checklist.md`

---

**Version :** 2.0
**Source :** Sessions 1-6 kaizen (Simpliscore tunnel_id)
**Status :** Stabilisé (testé sur 1 feature, N=1)

