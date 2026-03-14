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
**Complexité :** [Simple / Moyenne / Complexe]
**Version template :** 2.0 (enrichi avec learnings sessions 1-6)

---

## ⚠️ Checkpoints Critiques (à vérifier AVANT rédaction)

- [ ] **Bug architectural détecté ?** → STOP patch, faire spec globale
- [ ] **> 5 fichiers impactés ?** → Spec obligatoire
- [ ] **Décisions d'architecture nécessaires ?** → Lister questions pour user
- [ ] **Logique répétée 3+ fois identifiée ?** → Proposer Query Object proactif

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

### 🎯 Patterns Pré-Approuvés à Détecter Proactivement

**Si logique répétée 3+ fois :**
- [ ] Proposer Query Object (`app/queries/[namespace]/[name]_query.rb`)
- [ ] Documenter DRY bénéfices (testable, maintenable, extensible)

**Si conditions imbriquées > 2 niveaux :**
- [ ] Proposer self-documenting variables
- [ ] Documenter réduction complexité (nesting, lignes)

**Si state machine détectée :**
- [ ] Utiliser state checks explicites (`.state&.in?([...])`)
- [ ] Éviter boolean combinations (`persisted? && !failed?`)

**Si controller action modifie état DB mid-action :**
- [ ] Éviter memoization (`@var ||=`)
- [ ] Recalculer à chaque appel ou `force_reload:` explicite

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

**Pattern Migration DB Safe (3 commits recommandés) :**
```ruby
# Migration 1: Add column (nullable, pas de constraint)
class AddTunnelIdToLLMRuleSuggestions < ActiveRecord::Migration[7.0]
  def change
    add_column :llm_rule_suggestions, :tunnel_id, :string
    add_index :llm_rule_suggestions, :tunnel_id  # Non-unique d'abord
  end
end

# Migration 2: Backfill data (MaintenanceTask)
# [Voir section 9. Migration de Données]

# Migration 3: Add constraints (après backfill)
class AddConstraintsToTunnelId < ActiveRecord::Migration[7.0]
  def change
    # NOT NULL safe car backfill garantit données
    change_column_null :llm_rule_suggestions, :tunnel_id, false

    # Index unique final
    remove_index :llm_rule_suggestions, :tunnel_id
    add_index :llm_rule_suggestions,
              [:procedure_revision_id, :tunnel_id, :rule],
              unique: true,
              name: 'index_llm_suggestions_unique_tunnel_rule'
  end
end
```

**⚠️ Strong Migrations :** Si index concurrent nécessaire :
```ruby
disable_ddl_transaction!

def change
  add_index :table, :column, algorithm: :concurrently
end
```

---

### Validations

```ruby
class LLMRuleSuggestion < ApplicationRecord
  validates :tunnel_id, presence: true,
                        format: { with: /\A[a-f0-9]{6}\z/ },
                        uniqueness: { scope: [:procedure_revision_id, :rule] }
end
```

**⚠️ CHECKPOINT VALIDATION UNIQUENESS :**
- [ ] Validation Rails scope match Index DB ?
- [ ] Index unique existe en DB pour scope complet ?
- [ ] Si incohérence → migration pour corriger index

**Vérification :**
```bash
# Chercher index unique correspondant
grep -r "add_index.*unique: true" db/migrate/
cat db/schema.rb | grep -A3 "unique: true"
```

**Pourquoi critique :** Tests passent avec validation Rails seule, mais prod crashe si DB rejette (PG::UniqueViolation)

---

### Index

**Index à ajouter :**
- [ ] Index unique : `[:procedure_revision_id, :tunnel_id, :rule]`
- [ ] Index performance (si queries fréquentes) : `[:tunnel_id]`, `[:state]`

**⚠️ CRITIQUE :**
- Vérifier unicité cohérente avec validation Rails
- Vérifier performance (N+1 queries évitées ?)

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

### ⚠️ Détection Automatique : Logique Répétée 3+

**Commande de détection :**
```bash
# Chercher duplications
grep -r "pattern_métier" app/ | wc -l
# Si >= 3 → Extraire dans Query Object
```

### Query Object Pattern (Pré-Approuvé)

**Quand utiliser :**
- Logique métier répétée 3+ fois
- Queries complexes avec WHERE conditions
- Logique basée sur timestamps/états

**Structure recommandée :**
```ruby
# app/queries/llm/tunnel_finished_query.rb
class LLM::TunnelFinishedQuery
  def initialize(procedure_revision_id, tunnel_id)
    @procedure_revision_id = procedure_revision_id
    @tunnel_id = tunnel_id
  end

  def finished?
    # Logique centralisée
    LLMRuleSuggestion
      .where(
        procedure_revision_id: @procedure_revision_id,
        tunnel_id: @tunnel_id,
        rule: LLM::Rule::SEQUENCE.last,
        state: [:accepted, :skipped]
      )
      .exists?
  end

  def last_completed_step
    # Bonus: Méthodes additionnelles utiles
    LLMRuleSuggestion
      .where(procedure_revision_id: @procedure_revision_id, tunnel_id: @tunnel_id)
      .where(state: [:accepted, :skipped, :completed])
      .order(created_at: :desc)
      .first
  end
end
```

**Tests :**
```ruby
# spec/queries/llm/tunnel_finished_query_spec.rb
RSpec.describe LLM::TunnelFinishedQuery do
  describe '#finished?' do
    let(:revision) { create(:procedure_revision) }
    let(:tunnel_id) { SecureRandom.hex(3) }
    let(:query) { described_class.new(revision.id, tunnel_id) }

    context 'when last step accepted' do
      before do
        create(:llm_rule_suggestion,
          procedure_revision: revision,
          tunnel_id:,
          rule: LLM::Rule::SEQUENCE.last,
          state: 'accepted')
      end

      it 'returns true' do
        expect(query.finished?).to be true
      end
    end
  end
end
```

**Bénéfices mesurables :**
- DRY : 3+ duplications éliminées
- Testable : Isolation tests unitaires
- Maintenable : Logique centralisée
- Extensible : Ajout méthodes bonus facile

**Contre-exemple (Service à éviter ici) :**
```ruby
# ❌ Service trop complexe pour logique simple
class TunnelFinder
  # 103 lignes de logique time-based fragile
  # → Préférer Query Object simple (45 lignes queries SQL)
end
```

---

## 8. Tests

### ⚠️ PRINCIPE CRITIQUE : Tests Verts à Chaque Commit

**Règle absolue :**
Chaque commit DOIT avoir tests passants, sauf exception documentée.

**Approche implémentation :**
```
✅ CORRECT : Interleave code + specs
Commit N: Code change + spec update
Commit N+1: Code change + spec update

❌ INCORRECT : Code first, tests later
Commits 4-14: Code changes
Commits 15-16: Fix all tests
→ Git bisect cassé, historique illisible
```

**Exception autorisée :**
Breaking change atomique où tests DOIVENT être cassés → documenter dans commit message :
```
⚠️ TESTS BROKEN: Job signature changed
Fix in commits X-Y (3 call-sites to update)
```

---

### Tests à Créer

**Tests Model :**
- [ ] `spec/models/llm_rule_suggestion_spec.rb`
  - Validations (presence, format, uniqueness)
  - Scopes (si ajoutés)

**Tests Query Object :**
- [ ] `spec/queries/llm/tunnel_finished_query_spec.rb`
  - `#finished?` (contexts: last step accepted, skipped, not finished)
  - `#last_completed_step` (returns last, returns nil if none)

**Tests Controller :**
- [ ] `spec/controllers/administrateurs/types_de_champ_controller_spec.rb`
  - Nouvelles actions avec tunnel_id params
  - Redirections (when tunnel finished, when schema changed)

**Tests System :**
- [ ] `spec/system/administrateurs/simpliscore_spec.rb`
  - Workflow complet end-to-end
  - Auto-enchainement étapes
  - Schema change detection

**Tests Components :**
- [ ] `spec/components/llm/*_component_spec.rb`
  - Props avec tunnel_id
  - Liens avec tunnel_id dans URL

---

### Tests à Modifier

**Pattern : Tests Isolation avec Before Actions**

**Problème fréquent :**
Controller a `before_action :ensure_valid_tunnel` qui vérifie existence de records en DB. Tests DOIVENT setup ce contexte.

```ruby
# ❌ TEST QUI ÉCHOUE : Pas de tunnel setup
describe '#simplify' do
  it 'renders simplify view' do
    get :simplify, params: { tunnel_id: 'abc123', rule: 'improve_label' }
    # ❌ Échoue : ensure_valid_tunnel redirige (aucune suggestion en DB)
  end
end

# ✅ TEST CORRECT : Tunnel établi
describe '#simplify' do
  let(:tunnel_id) { SecureRandom.hex(3) }

  before do
    # Créer contexte pour passer before_action
    create(:llm_rule_suggestion,
      procedure_revision: draft,
      tunnel_id:,
      rule: 'improve_structure',
      state: 'accepted')
  end

  it 'renders simplify view' do
    get :simplify, params: { tunnel_id:, rule: 'improve_label' }
    # ✅ Passe : tunnel existe (1 suggestion en DB)
  end
end
```

**Checklist tests à modifier :**
- [ ] Controller specs : Ajouter `tunnel_id` param + setup contexte
- [ ] Component specs : Ajouter `tunnel_id` prop
- [ ] System specs : Adapter workflow (auto-enchainement, schema change)

**Pattern : Décisions Incrémentales pour Tests Obsolètes**

Si > 5 tests deviennent obsolètes après refactoring :
1. Grouper par similarité comportementale
2. Proposer action par groupe (ADAPTER / SUPPRIMER / GARDER PENDING)
3. Présenter 3 groupes max à la fois
4. Si user demande pause → sauvegarder dans `TESTS_REMAINING_TODO.md`

---

## 9. Migration de Données (Backfill)

**Strategy :**
- [ ] Script one-off ou migration ?
- [ ] Production data impact ?
- [ ] Rollback plan ?

---

## 10. Breaking Changes

**⚠️ CRITIQUE pour review**

### Détection Automatique des Call-Sites

**Commande obligatoire AVANT de documenter breaking change :**
```bash
# Trouver tous les call-sites d'un job
grep -r "ImproveProcedureJob.perform" app/ lib/ spec/

# Trouver tous les call-sites d'une méthode
grep -r "method_name" app/ lib/ spec/
```

**Résultat attendu :**
```
app/jobs/cron/llm_improvement_job.rb:12
app/controllers/administrateurs/types_de_champ_controller.rb:45
spec/jobs/llm/improve_procedure_job_spec.rb:23
```

---

### Changements Incompatibles

**Breaking Change 1 : Job Signature Change**

**AVANT :**
```ruby
LLM::ImproveProcedureJob.perform_async(procedure_revision_id, rule)
```

**APRÈS :**
```ruby
LLM::ImproveProcedureJob.perform_async(procedure_revision_id, tunnel_id, rule)
```

**Call-Sites Impactés (3 trouvés via grep) :**
1. `app/jobs/cron/llm_improvement_job.rb:12`
   - **Action :** Générer nouveau tunnel_id avant appel
2. `app/controllers/administrateurs/types_de_champ_controller.rb:45`
   - **Action :** Passer params[:tunnel_id]
3. `spec/jobs/llm/improve_procedure_job_spec.rb:23`
   - **Action :** Update tous appels dans tests

**Estimation fix :** 3 fichiers × 15min = 45min

---

### Plan d'Implémentation Breaking Change (Pattern Bloc)

**Structure en 3 commits (merge en bloc obligatoire) :**

```markdown
Commit 9: job: update ImproveProcedureJob signature (BREAKING) ⚠️
  Objectif: Ajouter tunnel_id param
  Fichiers: app/jobs/llm/improve_procedure_job.rb
  Notes: ⚠️ CODE CASSÉ après ce commit (3 call-sites à fixer)

Commit 10: job: update CRON call-site
  Objectif: Fix premier call-site (generate tunnel_id)
  Fichiers: app/jobs/cron/llm_improvement_job.rb

Commit 11: controller: update enqueue_simplify action
  Objectif: Fix deuxième call-site (pass tunnel_id)
  Fichiers: app/controllers/.../types_de_champ_controller.rb
  Notes: ✅ CODE FONCTIONNE après ce commit (tous call-sites fixés)
```

**⚠️ Documentation commit message :**
```
job: update ImproveProcedureJob signature (BREAKING)

BREAKING CHANGE: Add tunnel_id parameter to job signature

Call-sites to update:
- [ ] app/jobs/cron/llm_improvement_job.rb
- [ ] app/controllers/.../types_de_champ_controller.rb
- [ ] spec/jobs/llm/improve_procedure_job_spec.rb

⚠️ Tests will be broken until commits 10-11 fix all call-sites
Merge commits 9-11 en bloc ou ne pas déployer entre ces commits
```

---

### Plan de Migration (si dépréciation nécessaire)

**Approche progressive (si breaking change trop risqué) :**

**Phase 1 : Support double signature (1-2 sprints)**
```ruby
def perform(procedure_revision_id, tunnel_id = nil, rule = nil)
  # Support old signature : perform(revision_id, rule)
  # Support new signature : perform(revision_id, tunnel_id, rule)
  if rule.nil? && tunnel_id.is_a?(String) && LLM::Rule.valid?(tunnel_id)
    # Old signature detected
    rule = tunnel_id
    tunnel_id = SecureRandom.hex(3)
    Rails.logger.warn "DEPRECATED: ImproveProcedureJob called with old signature"
  end

  # ...
end
```

**Phase 2 : Migration call-sites (1 sprint)**
- Mettre à jour tous call-sites un par un
- Déployer progressivement

**Phase 3 : Suppression support old signature (1 sprint)**
- Supprimer fallback
- Assert new signature uniquement

**⚠️ Trade-off :**
Migration progressive = complexité accrue. Pour refactoring interne (pas API publique), préférer breaking change atomique en bloc.

---

## 11. Performance

### ⚠️ Trade-Offs Pragmatiques

**Principe :** Simplicité > Optimisation Prématurée (si justifié)

---

### Queries N+1 Identifiées

**N+1 Query 1 : Détection parcours actif dans new_simplify**

**Code concerné :**
```ruby
def new_simplify
  active_tunnels = draft.llm_rule_suggestions
    .select(:tunnel_id)
    .distinct
    .pluck(:tunnel_id)

  active_tunnels.each do |tunnel_id|
    query = LLM::TunnelFinishedQuery.new(draft.id, tunnel_id)
    if query.finished?
      # ...
    end
  end
end
```

**Impact :**
- 1 query pour distinct tunnel_ids
- N queries (1 par tunnel) pour vérifier si terminé
- **Contexte :** Max 3-5 tunnels actifs par procédure typiquement

**Trade-off documenté :**

**Option A : Optimiser (NOT CHOSEN)**
```ruby
# Query unique avec GROUP BY + subqueries
# Complexité : HAUTE
# Gain : 4-5 queries → 1 query
# Coût maintenance : +40% (queries complexes difficiles à lire)
```

**Option B : Garder N+1 (CHOSEN) ✅**
```ruby
# Code simple et lisible
# N+1 acceptable car :
# 1. N petit (< 10 tunnels actifs)
# 2. Queries rapides (indexed)
# 3. Action peu fréquente (1 fois par session user)
# 4. < 10k users total
```

**Rationale choix B :**
- **Volume utilisateurs :** < 10k total
- **Fréquence action :** 1 fois par session (pas de loop)
- **N borné :** < 10 tunnels par procédure (business constraint)
- **Coût maintenance :** Simplicité code > économie 4-5 queries
- **Performance mesurée :** < 50ms total (acceptable pour UX)

**Métriques à monitorer :**
- Si N > 20 tunnels actifs → revoir optimisation
- Si P95 latency > 200ms → revoir optimisation

---

### Index à Ajouter

**Index 1 : Unique composite (CRITIQUE)**
```ruby
add_index :llm_rule_suggestions,
          [:procedure_revision_id, :tunnel_id, :rule],
          unique: true,
          name: 'index_llm_suggestions_unique_tunnel_rule'
```

**Rationale :**
- Enforce unicité métier (1 suggestion par étape par tunnel)
- Performance : WHERE sur ces 3 colonnes fréquent (TunnelFinishedQuery)

**Index 2 : Performance (IMPORTANT)**
```ruby
add_index :llm_rule_suggestions, :tunnel_id
```

**Rationale :**
- Queries fréquentes par tunnel_id
- Améliore performance TunnelFinishedQuery

**Index 3 : Performance (NICE TO HAVE)**
```ruby
add_index :llm_rule_suggestions, [:state, :created_at]
```

**Rationale :**
- Queries dashboard admin (stats suggestions par état)
- Peut être ajouté plus tard si besoin détecté

**⚠️ Strong Migrations :**
Si table volumineuse (> 1M rows) → index concurrent :
```ruby
disable_ddl_transaction!

def change
  add_index :table, :column, algorithm: :concurrently
end
```

---

### Estimation Impact Performance

**Avant refactoring :**
- Détection tunnel actif : O(N log N) avec time-based fragile
- Cache busting : impossible (query contradictoire)

**Après refactoring :**
- Détection tunnel actif : O(N) avec N+1 acceptable
- Cache busting : possible (tunnel_id explicite)
- Latency action `new_simplify` : ~50ms (< 200ms target)

**Gains mesurables :**
- ✅ Cache busting fonctionne (bug critique résolu)
- ✅ Queries déterministes (pas time-based fragile)
- ⚠️ N+1 acceptable (trade-off simplicité)

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
