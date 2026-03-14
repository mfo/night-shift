# COMMIT_PLAN : [Titre Feature]

**Date :** YYYY-MM-DD
**Basé sur spec :** `specs/YYYY-MM-DD-[nom]-spec.md`
**Créé par :** Agent Claude
**Validé par :** [User]
**Version template :** 2.0 (sessions 1-6 learnings)

---

## ⚠️ Principes CRITIQUES

### 1. Tests Verts à Chaque Commit ✅
**Règle :** Chaque commit DOIT compiler + tests passants
**Exception :** Breaking change documenté avec `⚠️ TESTS BROKEN` + plage fix

### 2. Commits Atomiques (1 concept = 1 commit)
**Max :** 5 fichiers/commit (idéal : 1-3)
**Total :** < 20 commits (sinon revoir découpage)

### 3. Ordre Logique (7 Phases Standards)
```
Phase 1: Database → Phase 2: Infrastructure → Phase 3: Features
→ Phase 4: UI → Phase 5: Tests → Phase 6: Cleanup → Phase 7: UX
```

### 4. Breaking Changes Isolés en Blocs
**Structure :** Change signature → Fix call-site 1 → Fix call-site 2
**Merge :** En bloc obligatoire (ou ne pas déployer entre commits)

---

## 📊 Vue d'Ensemble

### Statistiques Plan

| Métrique | Valeur |
|----------|--------|
| **Commits total** | N (< 20) |
| **Phases** | 7 |
| **Fichiers impactés** | ~X |
| **Breaking changes** | N (commits X-Y) |
| **Temps estimé** | X-Yh |

---

### Tableau Récapitulatif Commits

| # | Phase | Titre | Breaking | Fichiers | Temps |
|---|-------|-------|----------|----------|-------|
| 1 | DB | add column | Non | 1 migration | 15min |
| 2 | DB | backfill data | Non | 1 task | 30min |
| 3 | DB | add constraints | Non | 1 migration | 15min |
| 4 | Infra | add validations | Non | 1 model + spec | 20min |
| 5 | Infra | create Query Object | Non | 1 query + spec | 45min |
| ... | ... | ... | ... | ... | ... |
| N | Cleanup | remove dead code | Non | 2 files | 20min |

**⚠️ Commits Breaking :** X-Y (merge en bloc)
**✅ Tests séparés :** Commit N-1 (system), Commit N (unit)

---

## Phase 1 : Database (3 commits)

**Objectif :** Préparer fondations DB (migrations safe, backfill, constraints)

---

### ✅ Commit 1: `db: add [column_name] to [table]`

**Objectif :** Ajouter colonne nullable pour permettre données existantes

**Fichiers à modifier :**
- [ ] `db/migrate/YYYYMMDDHHMMSS_add_column_to_table.rb` (create)

**Actions :**
```ruby
class AddTunnelIdToLLMRuleSuggestions < ActiveRecord::Migration[7.0]
  def change
    add_column :llm_rule_suggestions, :tunnel_id, :string
    add_index :llm_rule_suggestions, :tunnel_id  # Non-unique temporaire
  end
end
```

**Strong Migrations :**
- [ ] Si table > 1M rows → `algorithm: :concurrently`
- [ ] `disable_ddl_transaction!` si index concurrent

**Tests à exécuter :**
```bash
bundle exec rails db:migrate
bundle exec rails db:rollback
bundle exec rails db:migrate
# Vérifier : colonne ajoutée, index créé, nullable OK
```

**Notes :**
- ✅ Colonne nullable → pas de blocage sur données existantes
- ✅ Index non-unique temporaire → constraint ajouté commit 3
- ⏱️ Estimation : 15 min

---

### ✅ Commit 2: `maintenance: backfill [column] with MaintenanceTask`

**Objectif :** Remplir toutes données existantes avant d'ajouter constraint

**Fichiers à modifier :**
- [ ] `app/tasks/maintenance/backfill_tunnel_id_task.rb` (create)
- [ ] `spec/tasks/maintenance/backfill_tunnel_id_task_spec.rb` (create)

**Actions :**
```ruby
module Maintenance
  class BackfillTunnelIdTask < MaintenanceTasks::Task
    def collection
      LLMRuleSuggestion.where(tunnel_id: nil)
    end

    def process(suggestion)
      # Logique métier : détecter séquences improve_label → reconstruire tunnels
      # [Détails selon spec section 9. Migration de Données]
      suggestion.update!(tunnel_id: generate_tunnel_id)
    end
  end
end
```

**Tests à exécuter :**
```bash
bundle exec rspec spec/tasks/maintenance/backfill_tunnel_id_task_spec.rb
# Lancer task en dev :
rails maintenance_tasks:run[BackfillTunnelIdTask]
# Vérifier : tunnel_id rempli pour toutes suggestions
```

**Notes :**
- ✅ Task idempotente (peut relancer)
- ✅ Tests vérifient logique métier
- ⏱️ Estimation : 30 min

---

### ✅ Commit 3: `db: add constraints to [column]`

**Objectif :** Ajouter NOT NULL + index unique maintenant que backfill complet

**Fichiers à modifier :**
- [ ] `db/migrate/YYYYMMDDHHMMSS_add_constraints_to_column.rb` (create)

**Actions :**
```ruby
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

**Strong Migrations :**
```ruby
# Si Strong Migrations proteste sur NOT NULL :
safety_assured do
  change_column_null :llm_rule_suggestions, :tunnel_id, false
end
# Documenter : "Safe car backfill commit 2 garantit tunnel_id présent"
```

**Tests à exécuter :**
```bash
bundle exec rails db:migrate
# Vérifier : NOT NULL appliqué, index unique créé
bundle exec rails console
> LLMRuleSuggestion.create!(tunnel_id: nil)  # Doit fail
```

**Notes :**
- ✅ Constraint seulement APRÈS backfill (safe)
- ⚠️ `safety_assured` justifié par backfill
- ⏱️ Estimation : 15 min

---

## Phase 2 : Infrastructure (3 commits)

**Objectif :** Validations model + Query Object DRY + Factory updates

---

### ✅ Commit 4: `model: add validations to [Model]`

**Objectif :** Valider format, unicité, présence au niveau applicatif

**Fichiers à modifier :**
- [ ] `app/models/llm_rule_suggestion.rb` (edit)
- [ ] `spec/models/llm_rule_suggestion_spec.rb` (edit)
- [ ] `spec/factories/llm_rule_suggestions.rb` (edit)

**Actions :**
```ruby
# app/models/llm_rule_suggestion.rb
class LLMRuleSuggestion < ApplicationRecord
  validates :tunnel_id, presence: true,
                        format: { with: /\A[a-f0-9]{6}\z/, message: "must be 6 hex chars" },
                        uniqueness: { scope: [:procedure_revision_id, :rule] }
end
```

**⚠️ CHECKPOINT VALIDATION UNIQUENESS :**
- [ ] Validation scope `[:procedure_revision_id, :rule]` match Index DB commit 3 ?
- [ ] Index unique existe : `[:procedure_revision_id, :tunnel_id, :rule]` ?
- [ ] ✅ OUI → cohérent

**Tests à exécuter :**
```bash
bundle exec rspec spec/models/llm_rule_suggestion_spec.rb
# Tests : presence, format, uniqueness scope
```

**Notes :**
- ✅ Factory update : `tunnel_id { SecureRandom.hex(3) }`
- ⏱️ Estimation : 20 min

---

### ✅ Commit 5: `query: create [QueryName]Query for DRY`

**Objectif :** Centraliser logique métier répétée 3+ fois

**Fichiers à modifier :**
- [ ] `app/queries/llm/tunnel_finished_query.rb` (create)
- [ ] `spec/queries/llm/tunnel_finished_query_spec.rb` (create)

**Actions :**
```ruby
# app/queries/llm/tunnel_finished_query.rb
class LLM::TunnelFinishedQuery
  def initialize(procedure_revision_id, tunnel_id)
    @procedure_revision_id = procedure_revision_id
    @tunnel_id = tunnel_id
  end

  def finished?
    LLMRuleSuggestion.exists?(
      procedure_revision_id: @procedure_revision_id,
      tunnel_id: @tunnel_id,
      rule: LLM::Rule::SEQUENCE.last,
      state: [:accepted, :skipped]
    )
  end

  def last_completed_step
    # Bonus method : find last completed step
  end
end
```

**Tests à exécuter :**
```bash
bundle exec rspec spec/queries/llm/tunnel_finished_query_spec.rb
# Tests : #finished? (contexts: accepted, skipped, not finished)
# Tests : #last_completed_step (returns last, returns nil if none)
```

**Notes :**
- ✅ Pattern pré-approuvé (DRY pour logique répétée 3+)
- ⚠️ Ne pas encore utiliser (sera utilisé commits suivants)
- ⏱️ Estimation : 45 min

---

### ✅ Commit 6: `factory: update [Factory] with [field]`

**Objectif :** Générer tunnel_id dans factory pour tests futurs

**Fichiers à modifier :**
- [ ] `spec/factories/llm_rule_suggestions.rb` (edit)

**Actions :**
```ruby
FactoryBot.define do
  factory :llm_rule_suggestion, class: 'LLMRuleSuggestion' do
    procedure_revision
    tunnel_id { SecureRandom.hex(3) }  # ← Ajout
    rule { 'improve_label' }
    state { 'pending' }
  end
end
```

**Tests à exécuter :**
```bash
bundle exec rspec spec/models/llm_rule_suggestion_spec.rb
# Vérifier : create(:llm_rule_suggestion) fonctionne sans erreur validation
```

**Notes :**
- ✅ Tests existants passent sans modification (factory valide)
- ⏱️ Estimation : 10 min

---

## Phase 3 : Features (3 commits)

**Objectif :** Routes + Controller + Jobs avec tunnel_id

---

### ✅ Commit 7: `routes: add tunnel_id to [scope] routes`

**Objectif :** Nouvelles routes RESTful avec tunnel_id dans URL

**Fichiers à modifier :**
- [ ] `config/routes.rb` (edit)

**Actions :**
```ruby
namespace :admin do
  resources :procedures do
    resources :types_de_champ, only: [] do
      # Nouvelles routes avec tunnel_id
      get 'simplify/:tunnel_id/:rule', to: 'types_de_champ#simplify', as: :simplify
      post 'simplify/:tunnel_id/:rule/accept/:id', to: 'types_de_champ#accept_simplification', as: :accept_simplification
      post 'simplify/:tunnel_id/:rule/skip/:id', to: 'types_de_champ#skip_simplification', as: :skip_simplification

      # Entry point (pas de tunnel_id encore)
      get 'new_simplify', to: 'types_de_champ#new_simplify', as: :new_simplify
    end
  end
end
```

**Tests à exécuter :**
```bash
bundle exec rails routes | grep simplify
# Vérifier : nouvelles routes présentes avec tunnel_id
```

**Notes :**
- ✅ Routes cohérentes avec spec section 5. Controller
- ⏱️ Estimation : 15 min

---

### ✅ Commit 8: `controller: implement new_simplify entry point`

**Objectif :** Action intelligente qui détecte parcours actif OU crée nouveau

**Fichiers à modifier :**
- [ ] `app/controllers/administrateurs/types_de_champ_controller.rb` (edit)
- [ ] `spec/controllers/administrateurs/types_de_champ_controller_spec.rb` (edit)

**Actions :**
```ruby
# app/controllers/administrateurs/types_de_champ_controller.rb
def new_simplify
  # Détecter parcours actif
  active_tunnels = draft.llm_rule_suggestions.select(:tunnel_id).distinct.pluck(:tunnel_id)

  active_tunnels.each do |tunnel_id|
    query = LLM::TunnelFinishedQuery.new(draft.id, tunnel_id)
    next if query.finished?

    # Parcours actif trouvé → reprendre dernière étape
    last_step = query.last_completed_step
    next_rule = LLM::Rule.next_rule(last_step.rule)
    redirect_to simplify_admin_procedure_types_de_champ_path(..., tunnel_id:, rule: next_rule)
    return
  end

  # Aucun parcours actif → créer nouveau tunnel
  new_tunnel_id = SecureRandom.hex(3)
  redirect_to simplify_admin_procedure_types_de_champ_path(..., tunnel_id: new_tunnel_id, rule: LLM::Rule::SEQUENCE.first)
end
```

**Tests à exécuter :**
```bash
bundle exec rspec spec/controllers/administrateurs/types_de_champ_controller_spec.rb -e "new_simplify"
# Tests :
# - Parcours actif existe → reprend dernière étape
# - Aucun parcours → crée nouveau tunnel
# - Plusieurs parcours → choisit premier non-terminé
```

**Notes :**
- ✅ Utilise TunnelFinishedQuery créé commit 5
- ⚠️ N+1 query acceptable (trade-off doc spec section 11)
- ⏱️ Estimation : 30 min

---

### ⚠️ Commit 9: `job: update [JobName] signature (BREAKING)`

**Objectif :** Ajouter tunnel_id param au job

**Fichiers à modifier :**
- [ ] `app/jobs/llm/improve_procedure_job.rb` (edit)

**Actions :**
```ruby
# app/jobs/llm/improve_procedure_job.rb
class LLM::ImproveProcedureJob < ApplicationJob
  queue_as :default

  # AVANT : def perform(procedure_revision_id, rule)
  # APRÈS :
  def perform(procedure_revision_id, tunnel_id, rule)
    procedure_revision = ProcedureRevision.find(procedure_revision_id)

    suggestion = procedure_revision.llm_rule_suggestions
      .where(tunnel_id:, rule:)
      .first

    # ... logique existante ...
  end
end
```

**⚠️ BREAKING CHANGE Documentation :**

**Call-sites impactés (trouvés via grep) :**
```bash
grep -r "ImproveProcedureJob.perform" app/ lib/ spec/
# Résultats :
# 1. app/jobs/cron/llm_improvement_job.rb:12
# 2. app/controllers/administrateurs/types_de_champ_controller.rb:45
# 3. spec/jobs/llm/improve_procedure_job_spec.rb:23
```

**Tests à exécuter :**
```bash
bundle exec rspec spec/jobs/llm/improve_procedure_job_spec.rb
# ⚠️ TOUS TESTS VONT ÉCHOUER (signature changée)
# → Normal, fix commits 10-11
```

**Notes :**
- ⚠️ **CODE CASSÉ** après ce commit (3 call-sites à fixer)
- ⚠️ **MERGE EN BLOC** commits 9-11 obligatoire
- ⏱️ Estimation : 20 min

**Commit message template :**
```
job: update ImproveProcedureJob signature (BREAKING)

BREAKING CHANGE: Add tunnel_id parameter to job signature

Call-sites to update:
- [ ] app/jobs/cron/llm_improvement_job.rb
- [ ] app/controllers/administrateurs/types_de_champ_controller.rb
- [ ] spec/jobs/llm/improve_procedure_job_spec.rb

⚠️ Tests will be broken until commits 10-11 fix all call-sites
Merge commits 9-11 en bloc ou ne pas déployer entre ces commits
```

---

### ✅ Commit 10: `job: update CRON call-site with tunnel_id`

**Objectif :** Fix premier call-site (génère tunnel_id)

**Fichiers à modifier :**
- [ ] `app/jobs/cron/llm_improvement_job.rb` (edit)

**Actions :**
```ruby
# app/jobs/cron/llm_improvement_job.rb
class CRON::LLMImprovementJob < ApplicationJob
  def perform
    procedures.each do |procedure|
      tunnel_id = SecureRandom.hex(3)  # ← Générer nouveau tunnel
      LLM::ImproveProcedureJob.perform_async(procedure.draft_revision.id, tunnel_id, 'improve_label')
    end
  end
end
```

**Tests à exécuter :**
```bash
bundle exec rspec spec/jobs/cron/llm_improvement_job_spec.rb
# Vérifier : job s'enqueue avec tunnel_id
```

**Notes :**
- ✅ 1/3 call-sites fixé
- ⚠️ Tests job encore cassés (call-site 2 à fixer)
- ⏱️ Estimation : 15 min

---

### ✅ Commit 11: `controller: update enqueue_simplify with tunnel_id param`

**Objectif :** Fix deuxième call-site (passe tunnel_id depuis params)

**Fichiers à modifier :**
- [ ] `app/controllers/administrateurs/types_de_champ_controller.rb` (edit)
- [ ] `spec/jobs/llm/improve_procedure_job_spec.rb` (edit)

**Actions :**
```ruby
# app/controllers/administrateurs/types_de_champ_controller.rb
def enqueue_simplify
  @tunnel_id = params[:tunnel_id]
  rule = params[:rule]

  LLM::ImproveProcedureJob.perform_async(draft.id, @tunnel_id, rule)
  # ...
end
```

**Tests à exécuter :**
```bash
bundle exec rspec spec/controllers/administrateurs/types_de_champ_controller_spec.rb -e "enqueue"
bundle exec rspec spec/jobs/llm/improve_procedure_job_spec.rb
# ✅ TOUS TESTS PASSENT maintenant (3/3 call-sites fixés)
```

**Notes :**
- ✅ **CODE FONCTIONNE** après ce commit (breaking change résolu)
- ✅ Bloc commits 9-11 terminé (safe to deploy)
- ⏱️ Estimation : 45 min

---

## Phase 4 : UI (3 commits)

**Objectif :** Mise à jour components + views avec tunnel_id

---

### ✅ Commit 12: `component: update [Component] with tunnel_id prop`

**Objectif :** Passer tunnel_id comme prop aux components

**Fichiers à modifier :**
- [ ] `app/components/llm/suggestion_form_component.rb` (edit)
- [ ] `spec/components/llm/suggestion_form_component_spec.rb` (edit)

**Actions :**
```ruby
# app/components/llm/suggestion_form_component.rb
class LLM::SuggestionFormComponent < ViewComponent::Base
  def initialize(suggestion:, procedure:, tunnel_id:)
    @suggestion = suggestion
    @procedure = procedure
    @tunnel_id = tunnel_id  # ← Ajout
  end

  def accept_path
    accept_simplification_admin_procedure_types_de_champ_path(
      @procedure,
      tunnel_id: @tunnel_id,  # ← Utilisation
      rule: @suggestion.rule,
      id: @suggestion.id
    )
  end
end
```

**Tests à exécuter :**
```bash
bundle exec rspec spec/components/llm/suggestion_form_component_spec.rb
# Tests : tunnel_id passé correctement, liens générés avec tunnel_id
```

**Notes :**
- ⏱️ Estimation : 30 min

---

### ✅ Commit 13: `component: update [Header] navigation links`

**Objectif :** Mise à jour liens navigation dans header component

**Fichiers à modifier :**
- [ ] `app/components/llm/header_component.rb` (edit)
- [ ] `spec/components/llm/header_component_spec.rb` (edit)

**Actions :**
```ruby
# app/components/llm/header_component.rb
# Modifier tous liens pour inclure tunnel_id
```

**Tests à exécuter :**
```bash
bundle exec rspec spec/components/llm/header_component_spec.rb
```

**Notes :**
- ⏱️ Estimation : 15 min

---

### ✅ Commit 14: `views: update all links to use new routes`

**Objectif :** Mise à jour tous liens dans vues ERB/HAML

**Fichiers à modifier :**
- [ ] `app/views/administrateurs/types_de_champ/simplify.html.erb` (edit)
- [ ] [Autres vues à identifier via grep]

**Détection fichiers :**
```bash
grep -r "simplify_admin_procedure_types_de_champ_path" app/views/
# Liste tous fichiers à modifier
```

**Actions :**
```erb
<!-- AVANT -->
<%= link_to "Continuer", simplify_path(@procedure, rule: 'improve_label') %>

<!-- APRÈS -->
<%= link_to "Continuer", simplify_path(@procedure, tunnel_id: @tunnel_id, rule: 'improve_label') %>
```

**Tests à exécuter :**
```bash
bundle exec rspec spec/system/administrateurs/simpliscore_spec.rb
# Tests end-to-end : navigation complète avec tunnel_id
```

**Notes :**
- ⚠️ Nombre exact fichiers inconnu (découvert pendant implémentation)
- ⏱️ Estimation : 30 min

---

## Phase 5 : Tests (2 commits)

**Objectif :** Mise à jour tests système + tests unitaires

---

### ✅ Commit 15: `tests: update system specs for tunnel_id workflow`

**Objectif :** Tests end-to-end du workflow complet

**Fichiers à modifier :**
- [ ] `spec/system/administrateurs/simpliscore_spec.rb` (edit)

**Actions :**
```ruby
# spec/system/administrateurs/simpliscore_spec.rb
describe 'Simpliscore avec tunnel_id' do
  scenario 'Workflow complet avec auto-enchainement' do
    # 1. Entry point new_simplify (crée tunnel)
    visit new_simplify_admin_procedure_types_de_champ_path(procedure)

    # 2. URL contient tunnel_id
    expect(current_url).to match(/tunnel_id=[a-f0-9]{6}/)
    tunnel_id = URI.parse(current_url).query.match(/tunnel_id=([^&]+)/)[1]

    # 3. Accept step 1 → auto-enchainement step 2
    click_button "Accepter"

    expect(current_url).to include("tunnel_id=#{tunnel_id}")
    expect(current_url).to include("rule=improve_description")

    # 4. Workflow complet
    # [Suite du test...]
  end

  scenario 'Reprend parcours actif' do
    # Créer suggestion existante
    tunnel_id = SecureRandom.hex(3)
    create(:llm_rule_suggestion, procedure_revision: procedure.draft_revision,
                                   tunnel_id:, rule: 'improve_label', state: 'accepted')

    visit new_simplify_admin_procedure_types_de_champ_path(procedure)

    # Doit reprendre tunnel existant
    expect(current_url).to include("tunnel_id=#{tunnel_id}")
  end
end
```

**Tests à exécuter :**
```bash
bundle exec rspec spec/system/administrateurs/simpliscore_spec.rb
# Tous scénarios end-to-end passent
```

**Notes :**
- ✅ Tests documentent comportement attendu
- ⏱️ Estimation : 45 min

---

### ✅ Commit 16: `tests: update controller and component specs`

**Objectif :** Mise à jour tests unitaires (controllers, components, jobs)

**Fichiers à modifier :**
- [ ] `spec/controllers/administrateurs/types_de_champ_controller_spec.rb` (edit)
- [ ] `spec/components/llm/*_component_spec.rb` (edit)
- [ ] `spec/jobs/llm/improve_procedure_job_spec.rb` (déjà fait commit 11)

**Pattern : Tests Isolation avec Before Actions**

```ruby
# spec/controllers/.../types_de_champ_controller_spec.rb
describe '#simplify' do
  let(:tunnel_id) { SecureRandom.hex(3) }

  before do
    # Setup contexte pour passer before_action ensure_valid_tunnel
    create(:llm_rule_suggestion,
      procedure_revision: draft,
      tunnel_id:,
      rule: 'improve_structure',
      state: 'accepted')
  end

  it 'renders simplify view' do
    get :simplify, params: { procedure_id: procedure.id, tunnel_id:, rule: 'improve_label' }
    expect(response).to be_successful
  end
end
```

**Tests à exécuter :**
```bash
bundle exec rspec spec/controllers/
bundle exec rspec spec/components/
# Tous tests unitaires passent
```

**Notes :**
- ✅ **FIRST GREEN COMMIT** 🟢 (si approche tests verts à chaque commit respectée)
- ✅ Coverage maintenu ≥ 80%
- ⏱️ Estimation : 60 min

---

## Phase 6 : Cleanup (1 commit)

**Objectif :** Suppression code mort (TunnelFinder, anciennes routes)

---

### ✅ Commit 17: `cleanup: remove TunnelFinder and legacy code`

**Objectif :** Supprimer code obsolète remplacé par TunnelFinishedQuery

**Fichiers à modifier :**
- [ ] `app/services/llm/tunnel_finder.rb` (delete)
- [ ] `spec/services/llm/tunnel_finder_spec.rb` (delete)
- [ ] `config/routes.rb` (edit - supprimer anciennes routes si présentes)

**Détection code mort :**
```bash
# Vérifier aucune référence TunnelFinder
grep -r "TunnelFinder" app/ lib/ spec/
# Si résultats → remplacer par TunnelFinishedQuery
# Si aucun résultat → safe to delete
```

**Tests à exécuter :**
```bash
bundle exec rspec
# Suite complète : 0 failures
bundle exec rubocop
# 0 offenses
```

**Notes :**
- ✅ Code plus simple (103 lignes → 45 lignes avec Query Object)
- ✅ Tous tests passent (cleanup sans régression)
- ⏱️ Estimation : 20 min

---

## Phase 7 : UX (optionnel, si applicable)

**Objectif :** Améliorations cosmétiques, wording, a11y

---

### ✅ Commit 18 (optionnel): `fix(simpliscore): amélioration UX (wording, typographie, stepper)`

**Objectif :** Améliorations non liées au refactoring technique

**Fichiers à modifier :**
- [ ] `app/components/llm/*/fr.yml` (wording)
- [ ] `app/components/llm/*_component.rb` (CSS, a11y)

**Actions :**
- Améliorer wording (clarté, tone)
- Améliorer typographie (espaces insécables, guillemets français)
- Améliorer stepper (indicateur progression)

**Tests à exécuter :**
```bash
bundle exec rspec spec/components/
# Vérifier : aucune régression fonctionnelle
```

**Notes :**
- ✅ Découple technique (commits 1-17) et cosmétique (commit 18)
- ✅ Review plus facile (changements séparés)
- ⏱️ Estimation : 30-45 min

---

## 📊 Récapitulatif Final

### Statistiques

| Métrique | Valeur |
|----------|--------|
| **Commits total** | 17-18 |
| **Phases** | 7 |
| **Fichiers impactés** | ~25 |
| **Breaking changes** | 1 (commits 9-11) |
| **Temps estimé total** | 8-15h |

### Validation Checklist

**Avant de commencer implémentation :**
- [ ] User a validé ce plan ?
- [ ] Spec technique lue et comprise ?
- [ ] Breaking changes compris (commits 9-11 en bloc) ?
- [ ] Tests verts à chaque commit = principe accepté ?

**Pendant implémentation :**
- [ ] Chaque commit : tests passent OU raison documentée ?
- [ ] Breaking changes : merge commits 9-11 en bloc ?
- [ ] Coverage ≥ 80% maintenu ?

**Après implémentation :**
- [ ] Suite complète tests passe (0 failures) ?
- [ ] Rubocop clean (0 offenses) ?
- [ ] Breaking changes documentés dans PR description ?
- [ ] Prêt pour Phase 3 : Review & Cleanup ?

---

## 🚀 Next Steps

**Une fois ce plan validé :**
1. User approuve structure (phases, commits, breaking changes)
2. Lancer Phase 2 : Implementation (exécution commit par commit)
3. Checkpoints réguliers (après chaque phase)
4. Phase 3 : Review & Cleanup quand tous commits terminés

---

## 🔗 Références

**Spec source :** `specs/YYYY-MM-DD-[nom]-spec.md`
**Methodology :** `pocs/4-features/setup.md`
**Patterns :** `../feature-implementation/patterns.md`

---

**Template version :** 2.0
**Basé sur learnings :** Sessions 1-6 (Simpliscore tunnel_id)
**Status :** Production-ready, testé sur feature complexe (17 commits, 8-15h)

