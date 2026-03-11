# POC 4 : Création de Spécifications Techniques d'Architecture

**Objectif :** Créer des specs techniques production-ready avec review agent PM

**Score cible :** 7/10 seul, 9/10 avec review agent PM

**Temps estimé :** 3-6h (2x estimation initiale pour specs architecture)

---

## Quand utiliser ce POC ?

**✅ Utiliser pour :**
- Bug architectural découvert (nécessite refactoring global)
- Feature complexe avec décisions d'architecture
- Refactoring impactant plusieurs composants (> 5 fichiers)
- Décisions techniques avec trade-offs à documenter

**❌ NE PAS utiliser pour :**
- Bug simple (NoMethodError, nil check) → fix direct
- Feature CRUD simple → implémentation directe
- Patch incrémental → Edit direct

**Règle critique :** Si bug architectural détecté → STOP et proposer spec globale, pas patch

---

## Workflow (3 phases)

### Phase 1 : Analyse & Rédaction Spec v1 (2-3h)

#### Étape 1 : Analyse problème (30min)

**Objectif :** Comprendre le problème et l'architecture existante

**Actions :**
1. Lire le code existant (fichiers impactés)
2. Comprendre l'architecture actuelle (dépendances, flows)
3. Identifier la root cause (si bug) ou le besoin (si feature)
4. Grep patterns critiques (call-sites, duplications)

**Commandes utiles :**
```bash
# Trouver call-sites (breaking changes potentiels)
grep -r "ClassName\|method_name" app/ lib/ spec/

# Trouver duplications (DRY opportunities)
grep -r "pattern_répété" app/

# Identifier tests existants
find spec -name "*nom_fichier*_spec.rb"
```

**Checkpoint :**
- [ ] Problème compris ?
- [ ] Architecture existante claire ?
- Si NON → Demander clarifications au user

---

#### Étape 2 : Conception architecture (1h)

**Objectif :** Concevoir la solution avec décisions d'architecture

**Questions à poser au user :**
- Format des identifiants ? (UUID, hex, int)
- Trade-off performance vs. simplicité ?
- Breaking changes acceptables ?
- Auto-lancement ou contrôle user ?
- Validation stricte ou permissive ?

**Patterns à détecter proactivement :**
1. **Logique répétée 3+ fois** → Proposer Query Object ou extraction
2. **N+1 queries** → Documenter trade-off (optimiser vs. simplicité)
3. **Breaking changes** → Lister call-sites impactés
4. **Index DB manquants** → Proposer ajout pour perf

**Checkpoint :**
- [ ] Architecture conçue ?
- [ ] Décisions prises avec user ?
- [ ] Patterns DRY identifiés ?

---

#### Étape 3 : Rédaction spec v1 (1-1h30)

**Objectif :** Documenter la spec complète

**Structure obligatoire (15 sections) :**

```markdown
# Spec Technique : [Titre]

**Date :** YYYY-MM-DD
**Auteur :** [Agent/User]
**Status :** Draft v1
**Temps estimé implémentation :** X-Yh

---

## 1. Contexte & Problème

[Description du problème]

### Root Cause (si bug)
[Analyse avec preuve si possible]

### Objectifs
- [ ] Objectif 1
- [ ] Objectif 2

---

## 2. Décisions d'Architecture

### Décision 1 : [Titre]

**Choix :** [Solution choisie]

**Alternative :** [Solution non retenue]

**Rationale :**
- [Raison 1 - contexte métier]
- [Raison 2 - simplicité vs. complexité]
- [Raison 3 - coût/bénéfice]

**Impact :** [Conséquences mesurables]

---

## 3. Architecture Proposée

### Vue d'ensemble
[Diagramme ASCII ou description]

### Composants impactés
1. **Modèle** : [Changements]
2. **Controller** : [Changements]
3. **Jobs** : [Changements]
4. **Services** : [Changements]
5. **Views** : [Changements]

---

## 4. Modèle (Database & ActiveRecord)

### Migrations
[Code migrations]

### Validations
[Code validations]

### Index
[Index à ajouter avec unique/name]

**⚠️ CRITIQUE :** Vérifier unicité et performance

---

## 5. Controller

### Routes
[Config routes]

### Actions
[Code actions]

---

## 6. Jobs

### Job Signature
[Code job]

**⚠️ BREAKING CHANGE si signature modifiée**

### Call-sites impactés
[Liste fichiers à modifier avec grep]

---

## 7. Services / Query Objects

### Extraction DRY (si logique répétée 3+)
[Code Query Object]

---

## 8. Tests

### Tests à créer
[Liste tests]

### Tests à modifier
[Liste tests existants]

---

## 9. Migration de Données (Backfill)

**Strategy :**
- [ ] Script one-off ou migration ?
- [ ] Production data impact ?
- [ ] Rollback plan ?

---

## 10. Breaking Changes

**⚠️ CRITIQUE pour review**

### Changements incompatibles
[Liste avec call-sites]

### Plan de migration
[Phases de dépréciation]

---

## 11. Performance

### Queries N+1 identifiées
[Trade-off documenté avec rationale]

### Index à ajouter
[Liste index]

---

## 12. Sécurité

### Validations
[Format, unicité, présence]

### Authorization
[Qui peut créer/modifier/voir]

---

## 13. UX / Product

### Comportement attendu
[Liste comportements]

### Edge cases
[Solutions pour chaque edge case]

---

## 14. Rollout Strategy

**Phase 1 : Feature flag**
**Phase 2 : Scale up**
**Phase 3 : Cleanup**

---

## 15. Métriques & Monitoring

### Métriques à tracker
[Liste métriques]

### Alertes à configurer
[Liste alertes]

---

## 16. Annexes

### Références
[Liens]

### Estimations
- **Implémentation :** X-Yh
- **Tests :** X-Yh
- **Total :** X-Yh
```

**Checkpoint :**
- [ ] 15 sections complètes ?
- [ ] Breaking changes documentés ?
- [ ] Trade-offs justifiés ?

---

### Phase 2 : Review Agent PM (45min-1h)

**⚠️ OBLIGATOIRE pour specs > 500 lignes**

**Objectif :** Valider qualité technique de la spec

**Actions :**
1. Lancer agent PM Senior pour review
2. Analyser findings (10-20 problèmes attendus)
3. Corriger problèmes par gravité :
   - 🔴 Critiques (bloquants) → corriger tous
   - 🟠 Importants → corriger tous
   - 🟡 Nice-to-have → si temps

**Focus review PM :**
- Breaking changes documentés ?
- Index DB manquants ?
- Validations suffisantes ?
- Tests couverts ?
- Migration données claire ?
- Trade-offs justifiés ?
- Sécurité (format, unicité, authz) ?
- Edge cases couverts ?
- Rollout strategy définie ?
- Métriques identifiées ?

**Checkpoint :**
- [ ] Review findings analysés ?
- [ ] Problèmes critiques corrigés ?
- [ ] Spec v2 production-ready ?

---

### Phase 3 : User Review + Décisions (1-2h)

**Objectif :** Validation finale user et ajustements

**Présenter au user :**
- Spec v2 (post-review PM)
- Décisions d'architecture à trancher
- Estimation temps implémentation

**Itérations attendues :**
- Max 8 rounds
- User tranche sur trade-offs métier
- Agent ajuste spec selon décisions

**Checkpoint final :**
- [ ] User approuve l'architecture ?
- [ ] Breaking changes acceptés ?
- [ ] Trade-offs validés ?
- [ ] Estimation temps réaliste ?

---

### Phase 4 : Création Plan d'Implémentation (1-2h)

**Objectif :** Transformer spec validée en plan exécutable avec commits atomiques

**Actions :**
1. **Lire spec complète** (20-30min)
   - Comprendre tous les composants impactés
   - Identifier dépendances entre changements
   - Repérer breaking changes

2. **Découper en commits atomiques** (1h)
   - 1 commit = 1 concept isolé et testable
   - Max 5 fichiers par commit (idéal : 1-3)
   - Ordre logique : DB → Infra → Features → Tests → Cleanup

3. **Documenter chaque commit** (20-30min)
   - Titre conventionnel (`scope: description`)
   - Objectif (1 phrase)
   - Fichiers à modifier (liste précise)
   - Actions (code ou instructions)
   - Tests à exécuter
   - Notes (warnings, breaking changes)

**Principes de découpage :**

1. **Phases logiques (ordre de dépendances) :**
   - **Phase 1** : Database (migrations, backfill, constraints)
   - **Phase 2** : Infrastructure (models, validations, query objects)
   - **Phase 3** : Features (routes, controllers, jobs)
   - **Phase 4** : UI (components, views)
   - **Phase 5** : Tests (system, unit)
   - **Phase 6** : Cleanup (suppression code mort)

2. **Breaking changes isolés :**
   - Commit N : Introduit breaking change (⚠️ code cassé)
   - Commits N+1, N+2 : Fix call-sites
   - Documenter : "Code cassé entre N et N+X, merge en bloc"

3. **Tests à la fin :**
   - System specs en 1 commit
   - Unit specs en 1 commit
   - Pas mélangés avec features

**Patterns critiques :**

**Pattern 1 : Migration DB Safe (3 commits)**
```
Commit 1: db: add column (nullable)
Commit 2: maintenance: backfill data
Commit 3: db: add constraints (NOT NULL, UNIQUE)
```
→ Rollback safe, pas de downtime

**Pattern 2 : Breaking Change Bloc**
```
Commit N: scope: change signature (BREAKING) ⚠️
Commit N+1: scope: fix first call-site
Commit N+2: scope: fix second call-site
```
→ Merge en bloc obligatoire

**Pattern 3 : Tests Séparés**
```
Commit N-1: tests: update system specs
Commit N: tests: update unit specs
```
→ Features reviewables sans bruit tests

**Présenter au user :**
- Nombre total de commits (< 20 idéal)
- Phases identifiées (6 phases standard)
- Breaking changes (avec plage commits impactés)
- Estimation temps total (commits × 30-60min)
- Tableau récapitulatif

**Checkpoint :**
- [ ] Commits atomiques définis ?
- [ ] Max 20 commits ?
- [ ] Phases logiques respectées ?
- [ ] Breaking changes isolés ?
- [ ] Tests exécutables après chaque commit ?
- [ ] User approuve structure ?

---

## Patterns Critiques

### Pattern 1 : Preuve Mathématique de Bug

**Quand :** Bug subtil à prouver

**Approche :** Prouver mathématiquement que condition impossible

**Exemple :**
```sql
WHERE created_at >= T AND created_at < T
-- Impossible : T ne peut pas être >= et < lui-même
```

**Impact :** Conviction immédiate, pivot architectural accepté

---

### Pattern 2 : Query Object pour DRY

**Quand :** Logique répétée 3+ fois

**Détection :**
```bash
grep -r "pattern" app/ | wc -l  # Si >= 3 → extraire
```

**Solution :**
```ruby
class Namespace::QueryNameQuery
  def method?
    # Logique centralisée
  end
end
```

**Avantages :** DRY, testable, extensible

---

### Pattern 3 : Documentation Trade-offs

**Template :**
```markdown
## Décision : [Titre]
**Choix :** [Solution]
**Alternative :** [Non retenue]
**Rationale :** [Pourquoi]
**Impact :** [Conséquences]
```

**Avantages :** Évite débats futurs, clarté équipe

---

## Checklist Production-Ready

Avant de soumettre spec au user :

- [ ] 15 sections minimum complètes
- [ ] Breaking changes documentés avec call-sites
- [ ] Trade-offs documentés avec rationale
- [ ] Tests listés (créer + modifier)
- [ ] Migration de données planifiée
- [ ] Performance analysée (N+1, index)
- [ ] Sécurité vérifiée (validations, authz)
- [ ] Rollout strategy définie
- [ ] Métriques identifiées
- [ ] Estimation temps implémentation

---

## Métriques Attendues

**Temps :**
- Analyse : 30min
- Conception : 1h
- Rédaction v1 : 1-1h30
- Review PM : 45min
- Itérations : 1-2h
- Plan implémentation : 1-2h
- **Total : 4-8h (spec + plan)**

**Qualité :**
- Spec complète : 15 sections
- Review findings : 10-20 problèmes
- Agent-friendly score : 7/10 seul, 9/10 avec review PM

---

## Livrable Final

**Fichiers à créer :**
1. `specs/YYYY-MM-DD-[nom]-spec.md` (spec finale)
2. `specs/YYYY-MM-DD-[nom]-review-v1.md` (review PM)
3. `specs/YYYY-MM-DD-[nom]-review-v2.md` (validation finale)
4. `specs/YYYY-MM-DD-[nom]-implementation-plan.md` (plan atomique)
5. `kaizen/YYYY-MM-DD-[nom]-spec.md` (kaizen phase spec)
6. `pocs/4-spec/result-plan.md` (learnings création plan)

**Next step :** Implémentation par agent codeur (8-20h selon complexité)

---

## Learnings de Phase 1 (Simpliscore tunnel_id)

**Score obtenu :** 7/10 seul, 9/10 avec review PM ✅

**Ce qui a marché :**
- Review agent PM (15 problèmes détectés)
- Itérations rapides user (8 rounds sans friction)
- Query Object proactif (user a approuvé immédiatement)
- Documentation trade-offs (évite débats futurs)
- Preuve mathématique bug (conviction immédiate)

**Ce qui a coincé :**
- Fausse alerte sur code existant (lecture trop rapide)
- Tentative patch au lieu de spec globale
- Sous-estimation temps (3h → 5h30)

**Hypothèses validées :**
- Review agent PM efficace pour specs > 500 lignes
- Itérations rapides user + agent fonctionnent bien
- Query Object proactif apprécié
- Fire-and-forget irréaliste (décisions métier nécessaires)

---

**Principe :** Spec production-ready permet implémentation rapide. Review agent PM critique pour qualité.
