# Patterns Agent-Friendly - POC 4 Features

**Version :** 2.0
**Source :** Sessions 1-6 kaizen (Simpliscore tunnel_id)

---

## 🎯 Introduction

Ce document catalogue les **patterns découverts et validés** au fil des sessions d'implémentation.

**Critères pattern agent-friendly :**
- ✅ Réutilisable sur multiples tâches
- ✅ Réduit complexité ou charge mentale
- ✅ Améliore autonomie agent (score ≥ 8/10)
- ✅ Validé empiriquement (≥ 2 occurrences)

---

## 📊 Index Patterns par Score

| Pattern | Score | Phase | Fréquence |
|---------|-------|-------|-----------|
| [Migration DB Safe (3 commits)](#pattern-1--migration-db-safe-3-commits) | 10/10 | Create-Plan | Élevée |
| [Query Object pour DRY](#pattern-2--query-object-pour-dry) | 10/10 | Create-Spec | Moyenne |
| [Tests Verts à Chaque Commit](#pattern-3--tests-verts-à-chaque-commit) | 10/10 | Implementation | Critique |
| [State Checks Explicites](#pattern-4--state-checks-explicites) | 9/10 | Implementation | Élevée |
| [Breaking Change Bloc](#pattern-5--breaking-change-bloc) | 9/10 | Create-Plan | Moyenne |
| [Tests Séparés (System + Unit)](#pattern-6--tests-séparés-system--unit) | 9/10 | Create-Plan | Élevée |
| [Self-Documenting Variables](#pattern-7--self-documenting-variables) | 9/10 | Implementation | Moyenne |
| [Checkpoint Validation Uniqueness](#pattern-8--checkpoint-validation-uniqueness) | 9/10 | Create-Spec | Moyenne |
| [Tests Isolation avec Before Actions](#pattern-9--tests-isolation-avec-before-actions) | 8/10 | Implementation | Élevée |
| [Entry Point Intelligent](#pattern-10--entry-point-intelligent) | 8/10 | Create-Spec | Faible |

---

## Pattern 1 : Migration DB Safe (3 commits)

### Score Agent-Friendly
**10/10** - Pattern clair, safe, réutilisable

### Contexte
Ajout colonne obligatoire avec données existantes en production

### Problème résolu
Éviter downtime et erreurs lors ajout contrainte NOT NULL sur table volumineuse

### Structure

**Commit 1: Add column (nullable)**
```ruby
class AddTunnelIdToLLMRuleSuggestions < ActiveRecord::Migration[7.0]
  def change
    add_column :llm_rule_suggestions, :tunnel_id, :string
    add_index :llm_rule_suggestions, :tunnel_id  # Non-unique temporaire
  end
end
```

**Commit 2: Backfill data**
```ruby
module Maintenance
  class BackfillTunnelIdTask < MaintenanceTasks::Task
    def collection
      LLMRuleSuggestion.where(tunnel_id: nil)
    end

    def process(suggestion)
      suggestion.update!(tunnel_id: generate_tunnel_id)
    end
  end
end
```

**Commit 3: Add constraints**
```ruby
class AddConstraintsToTunnelId < ActiveRecord::Migration[7.0]
  def change
    change_column_null :llm_rule_suggestions, :tunnel_id, false

    remove_index :llm_rule_suggestions, :tunnel_id
    add_index :llm_rule_suggestions,
              [:procedure_revision_id, :tunnel_id, :rule],
              unique: true
  end
end
```

### Avantages
- ✅ Rollback safe (peut s'arrêter après commit 1 ou 2)
- ✅ Pas de downtime (colonne nullable permet app de tourner)
- ✅ Testable à chaque étape
- ✅ Production-safe (Strong Migrations compatible)

### Quand utiliser
- Ajout colonne NOT NULL sur table existante
- Ajout index unique avec données existantes
- Migration avec backfill nécessaire

### Validé sur
- Session 1 (Simpliscore tunnel_id)
- Session 2 (Schema hash)

---

## Pattern 2 : Query Object pour DRY

### Score Agent-Friendly
**10/10** - Pattern Rails standard, facile à identifier

### Contexte
Logique métier répétée 3+ fois dans codebase

### Problème résolu
- Code dupliqué (violations DRY)
- Logique business dans controllers/views
- Difficultés tests isolation

### Détection Automatique
```bash
# Chercher duplications
grep -r "pattern_métier" app/ | wc -l
# Si >= 3 → Extraire dans Query Object
```

### Structure
```ruby
# app/queries/[namespace]/[name]_query.rb
class LLM::TunnelFinishedQuery
  def initialize(procedure_revision_id, tunnel_id)
    @procedure_revision_id = procedure_revision_id
    @tunnel_id = tunnel_id
  end

  def finished?
    # Logique centralisée
    LLMRuleSuggestion.exists?(
      procedure_revision_id: @procedure_revision_id,
      tunnel_id: @tunnel_id,
      rule: LLM::Rule::SEQUENCE.last,
      state: [:accepted, :skipped]
    )
  end

  def last_completed_step
    # Bonus: Méthodes additionnelles
  end
end
```

### Tests
```ruby
# spec/queries/[namespace]/[name]_query_spec.rb
RSpec.describe LLM::TunnelFinishedQuery do
  describe '#finished?' do
    let(:query) { described_class.new(revision_id, tunnel_id) }

    context 'when last step accepted' do
      # Tests isolation
    end
  end
end
```

### Avantages
- ✅ DRY (3+ duplications éliminées)
- ✅ Testable isolément
- ✅ Maintenable (logique centralisée)
- ✅ Extensible (ajout méthodes facile)
- ✅ Plus simple que Service (45 lignes vs 103 lignes)

### Quand utiliser
- Logique répétée 3+ fois
- Queries complexes avec WHERE conditions
- Logique basée sur timestamps/états
- Remplacement Service trop complexe

### Contre-indications
- Logique utilisée 1-2 fois seulement
- Logique triviale (1 ligne)

### Validé sur
- Session 1 (TunnelFinishedQuery remplace TunnelFinder)
- Session 5 (Logique Component → Query Object)

---

## Pattern 3 : Tests Verts à Chaque Commit

### Score Agent-Friendly
**10/10** - CRITIQUE pour historique Git sain

### Contexte
Tout refactoring, feature, ou migration

### Problème résolu
- Git bisect cassé (historique avec tests rouges)
- Historique illisible pour reviewers
- Difficulté identifier quand bug introduit

### Règle Absolue
**Chaque commit DOIT avoir tests passants**

### Approche

**✅ CORRECT : Interleave code + specs**
```
Commit 4: model: add validations + update factory/specs
Commit 5: query: create TunnelFinishedQuery + specs
Commit 6: routes: convert to tunnel_id + update controller specs
```

**❌ INCORRECT : Code first, tests later**
```
Commits 4-14: Code changes (⚠️ tests rouges)
Commits 15-16: Fix all tests
→ Git bisect cassé, historique illisible
```

### Exception Autorisée
Breaking change atomique où tests DOIVENT être cassés → documenter :
```
⚠️ TESTS BROKEN: Job signature changed
Fix in commits X-Y (3 call-sites to update)
```

### Avantages
- ✅ Git bisect fonctionnel
- ✅ Historique lisible pour reviewers
- ✅ Confiance à chaque étape
- ✅ Debug facilité (problème identifié immédiatement)

### Impact Mesuré
- Session 1 : 12 commits tests rouges → score autonomie 7/10
- Sessions 2-6 : Tests verts chaque commit → score autonomie 8-9/10

### Validé sur
- Sessions 1-6 (learning critique session 1)

---

## Pattern 4 : State Checks Explicites

### Score Agent-Friendly
**9/10** - Intention claire, bugs réduits

### Contexte
Code avec state machines (Dossier, LLMRuleSuggestion, etc.)

### Problème résolu
- Conditions booléennes combinées fragiles
- Intention pas claire
- Bugs edge cases

### Règle

**❌ ÉVITER : Boolean combinations**
```ruby
return if record&.persisted? && !record&.failed?
return if object.present? && object.status != 'error'
```

**✅ PRÉFÉRER : State explicite**
```ruby
return if record&.state&.in?(['queued', 'running'])
return if object&.status&.in?(['pending', 'processing'])
```

### Avantages
- ✅ Intention claire (self-documenting)
- ✅ Facile à maintenir (ajout nouveaux états)
- ✅ Moins de bugs (edge cases évidents)
- ✅ Agent peut raisonner sur états possibles

### Impact Mesuré
Session 2 : Bug job non-enqueued détecté grâce à state check explicite

### Validé sur
- Session 2 (ImproveProcedureJob)
- Sessions 3-6 (Simpliscore concern)

---

## Pattern 5 : Breaking Change Bloc

### Score Agent-Friendly
**9/10** - Structure claire, responsabilité évidente

### Contexte
Changement signature méthode/job avec multiples call-sites

### Problème résolu
- Breaking changes éparpillés (confusion)
- Git bisect identifie commit cassé mais pas fix
- Merge partiel impossible (code cassé entre commits)

### Structure

**Commit N: Change signature (BREAKING)** ⚠️
```ruby
# AVANT : def perform(revision_id, rule)
# APRÈS :
def perform(revision_id, tunnel_id, rule)
  # ⚠️ Code cassé après ce commit (3 call-sites à fixer)
end
```

**Commit N+1: Fix first call-site**
```ruby
# app/jobs/cron/llm_improvement_job.rb
tunnel_id = SecureRandom.hex(3)
LLM::ImproveProcedureJob.perform_async(revision_id, tunnel_id, rule)
```

**Commit N+2: Fix second call-site**
```ruby
# app/controllers/.../types_de_champ_controller.rb
LLM::ImproveProcedureJob.perform_async(draft.id, params[:tunnel_id], rule)
# ✅ Code fonctionne après ce commit (tous call-sites fixés)
```

### Documentation Obligatoire

**Commit message N :**
```
job: update ImproveProcedureJob signature (BREAKING)

BREAKING CHANGE: Add tunnel_id parameter

Call-sites to update:
- [ ] app/jobs/cron/llm_improvement_job.rb
- [ ] app/controllers/.../types_de_champ_controller.rb
- [ ] spec/jobs/llm/improve_procedure_job_spec.rb

⚠️ Tests broken until commits N+1, N+2 fix all call-sites
Merge commits N to N+2 en bloc ou ne pas déployer entre
```

### Avantages
- ✅ Breaking change isolé et visible
- ✅ Impact mesurable (N call-sites listés)
- ✅ Merge safe (en bloc ou pas du tout)
- ✅ Git bisect peut identifier problème + fix

### Quand utiliser
- Changement signature job/service
- Changement API interne
- Refactoring touchant multiples call-sites

### Validé sur
- Session 1 (ImproveProcedureJob signature)
- Session 4 (Reconstruction Git history)

---

## Pattern 6 : Tests Séparés (System + Unit)

### Score Agent-Friendly
**9/10** - Séparation claire, review facilitée

### Contexte
Mise à jour tests après implémentation features

### Problème résolu
- Features mélangées avec tests (review confuse)
- Tests system et unit dans même commit (bruit)

### Structure

**Commit N-1: Tests system (end-to-end)**
```ruby
# spec/system/administrateurs/simpliscore_spec.rb
describe 'Simpliscore avec tunnel_id' do
  scenario 'Workflow complet avec auto-enchainement' do
    # Test workflow complet
  end
end
```

**Commit N: Tests unit (isolation)**
```ruby
# spec/controllers/.../types_de_champ_controller_spec.rb
describe '#simplify' do
  # Tests isolation composants
end

# spec/components/llm/*_component_spec.rb
# Tests props, liens, rendering
```

### Avantages
- ✅ Features reviewables sans bruit des tests
- ✅ Tests system (end-to-end) séparés tests unit (isolation)
- ✅ Chaque commit testable indépendamment

### Quand utiliser
- Refactoring avec tests existants à modifier
- Feature avec tests system + unit à créer

### Validé sur
- Sessions 1-6 (Commits 15-16 systématiquement)

---

## Pattern 7 : Self-Documenting Variables

### Score Agent-Friendly
**9/10** - Réduction complexité mesurable

### Contexte
Actions controller avec conditionnels imbriqués (> 2 niveaux nesting)

### Problème résolu
- Nesting profond (4 niveaux)
- Code difficile à lire (charge cognitive élevée)
- Maintenance complexe

### Règle

**❌ AVANT : Conditions imbriquées (4 niveaux)**
```ruby
def simplify
  if current_suggestion&.state&.in?(['accepted', 'skipped'])
    last_step = query.last_completed_step
    if last_step
      next_rule = LLM::Rule.next_rule(last_step.rule)
      if next_rule
        redirect_to path(rule: next_rule)
      else
        if params[:rule] != last_step.rule
          redirect_to path(rule: last_step.rule)
        end
      end
    end
  end
end
```

**✅ APRÈS : Variables auto-documentées (1 niveau)**
```ruby
def simplify
  # Self-documenting variables
  current_step_finished = current_suggestion&.state&.in?(['accepted', 'skipped'])
  last_completed_step = query.last_completed_step if current_step_finished
  next_rule = LLM::Rule.next_rule(last_completed_step.rule) if last_completed_step
  visiting_different_step = last_completed_step && params[:rule] != last_completed_step.rule

  # Structure if/elsif/else unique
  if next_rule
    redirect_to path(rule: next_rule)
  elsif visiting_different_step
    redirect_to path(rule: last_completed_step.rule)
  else
    @suggestion = current_suggestion || build_new
  end
end
```

### Impact Mesuré
- **Réduction lignes :** 33 → 18 (-45%)
- **Réduction nesting :** 4 → 1 (-75%)
- **Lisibilité :** Grandement améliorée
- **Tests :** Aucune modification nécessaire

### Avantages
- ✅ Code auto-documenté (pas de commentaires nécessaires)
- ✅ Tests plus faciles (variables testables individuellement)
- ✅ Refactoring incrémental (une variable à la fois)

### Limites
- Ne pas créer variables pour conditions triviales (`if user.admin?`)
- Max 4-5 variables self-documenting par action
- Si > 5 variables → considérer extraction Service/Query Object

### Quand utiliser
- Actions controller avec > 2 niveaux nesting
- Conditions complexes répétées
- Code difficile à lire (charge cognitive élevée)

### Validé sur
- Session 6 (Simplify, accept_simplification, new_simplify)

---

## Pattern 8 : Checkpoint Validation Uniqueness

### Score Agent-Friendly
**9/10** - Évite crashes production

### Contexte
Ajout/modification validation `uniqueness` dans model

### Problème résolu
- Incohérence validation Rails vs. index DB
- Tests passent mais production crashe (PG::UniqueViolation)

### Règle

**Quand tu ajoutes/modifies :**
```ruby
validates :field, uniqueness: { scope: [:field_a, :field_b] }
```

**Checklist obligatoire :**

1. ✅ Chercher index unique correspondant :
```bash
grep -r "add_index.*unique: true" db/migrate/
cat db/schema.rb | grep -A3 "unique: true"
```

2. ✅ Vérifier cohérence :
```ruby
# Validation Rails
validates :tunnel_id, uniqueness: { scope: [:procedure_revision_id, :rule] }

# Index DB (DOIT matcher)
add_index :llm_rule_suggestions,
          [:procedure_revision_id, :tunnel_id, :rule],
          unique: true
```

3. ⚠️ Si incohérence → migration :
```ruby
# Supprimer ancien index
# Ajouter nouveau index cohérent
```

### Pourquoi critique
- Tests passent avec validation Rails seule (SQLite permissive)
- Production crashe si DB rejette (PostgreSQL strict)
- Détection précoce = 0 surprise prod

### Validé sur
- Session 3 (User a détecté incohérence validation/index)

---

## Pattern 9 : Tests Isolation avec Before Actions

### Score Agent-Friendly
**8/10** - Setup explicite, pattern répétable

### Contexte
Controller avec `before_action` vérifiant état DB

### Problème résolu
- Tests échouent mystérieusement (18 failures)
- Before action bloque car context pas setup
- Difficultés comprendre pourquoi test fail

### Règle

**Si controller a :**
```ruby
class TypesDeChampController
  before_action :ensure_valid_tunnel, only: [:simplify]

  def ensure_valid_tunnel
    @tunnel_id = params[:tunnel_id]
    suggestions = draft.llm_rule_suggestions.where(tunnel_id: @tunnel_id)
    redirect_to(...) if suggestions.empty?  # ❌ Bloque si pas de context
  end
end
```

**Alors tests DOIVENT setup context :**

**❌ TEST QUI ÉCHOUE : Pas de tunnel setup**
```ruby
it 'renders simplify view' do
  get :simplify, params: { tunnel_id: 'abc123', rule: 'improve_label' }
  # ❌ Échoue : ensure_valid_tunnel redirige (aucune suggestion en DB)
end
```

**✅ TEST CORRECT : Tunnel établi**
```ruby
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
```

### Checklist
- [ ] Controller a before_action vérifiant DB state ?
- [ ] Test setup crée records nécessaires ?
- [ ] Params passés à l'action matchent setup ?

### Impact Mesuré
Session 2 : 18 tests fixés en appliquant ce pattern systématiquement

### Validé sur
- Session 2 (18 controller specs)
- Sessions 3-6 (Tous tests controller)

---

## Pattern 10 : Entry Point Intelligent

### Score Agent-Friendly
**8/10** - Pattern clair une fois compris

### Contexte
Feature avec workflow multi-étapes (tunnels, wizards, etc.)

### Problème résolu
- User doit gérer tunnel_id manuellement
- Parcours multiples accidentels
- UX pas fluide

### Solution

**Action entry point qui :**
1. Détecte si workflow actif existe
2. Si oui → reprend dernière étape
3. Sinon → crée nouveau workflow

**Exemple (new_simplify) :**
```ruby
def new_simplify
  # Détecter parcours actif
  active_tunnels = draft.llm_rule_suggestions.distinct.pluck(:tunnel_id)

  active_tunnels.each do |tunnel_id|
    query = LLM::TunnelFinishedQuery.new(draft.id, tunnel_id)
    next if query.finished?

    # Parcours actif trouvé → reprendre
    last_step = query.last_completed_step
    next_rule = LLM::Rule.next_rule(last_step.rule)
    redirect_to simplify_path(tunnel_id:, rule: next_rule)
    return
  end

  # Aucun parcours actif → créer nouveau
  new_tunnel_id = SecureRandom.hex(3)
  redirect_to simplify_path(tunnel_id: new_tunnel_id, rule: first_rule)
end
```

### Avantages
- ✅ UX fluide (user ne voit pas tunnel_id initialement)
- ✅ Testable complètement
- ✅ Évite parcours multiples accidentels

### Trade-off accepté
N+1 query (1 par tunnel actif) mais N petit (< 10) → simplicité > optimisation

### Quand utiliser
- Workflows multi-étapes (wizard, tunnel, process)
- User peut avoir plusieurs parcours actifs
- Besoin reprendre parcours interrompu

### Validé sur
- Session 1 (new_simplify action)

---

## 📚 Patterns à Éviter (Anti-Patterns)

### Anti-Pattern 1 : Tests Cassés Commits 4-15

**Problème :** Approche "code first, tests later"
**Impact :** Git bisect inutilisable, historique illisible
**Solution :** Pattern 3 (Tests Verts à Chaque Commit)

### Anti-Pattern 2 : Boolean Combinations pour State

**Problème :** `if record&.persisted? && !record&.failed?`
**Impact :** Fragile, intention unclear, bugs edge cases
**Solution :** Pattern 4 (State Checks Explicites)

### Anti-Pattern 3 : Memoization dans Controller Actions

**Problème :** `@var ||= calculate` avec état DB changeant
**Impact :** Valeurs stale, bugs subtils
**Solution :** Recalculer à chaque appel ou `force_reload:` explicite

### Anti-Pattern 4 : Validation Rails Sans Index DB

**Problème :** `validates :x, uniqueness: ...` mais pas d'index unique
**Impact :** Tests passent, prod crashe
**Solution :** Pattern 8 (Checkpoint Validation Uniqueness)

---

## 🎯 Utilisation de ce Catalogue

### Pour Spec (Phase 0)
- Détecter logique répétée 3+ → Pattern 2 (Query Object)
- Planifier validation uniqueness → Pattern 8 (Checkpoint)
- Identifier workflows multi-étapes → Pattern 10 (Entry Point)

### Pour Plan (Phase 1)
- Organiser commits → Pattern 1 (Migration DB Safe), Pattern 5 (Breaking Change Bloc), Pattern 6 (Tests Séparés)
- Documenter breaking changes → Pattern 5

### Pour Implementation (Phase 2)
- Garder tests verts → Pattern 3 (CRITIQUE)
- State checks → Pattern 4
- Nesting > 2 → Pattern 7 (Self-Documenting Variables)
- Tests controller → Pattern 9 (Tests Isolation)

### Pour Review (Phase 3)
- Vérifier tous patterns appliqués
- Identifier anti-patterns
- Proposer Query Objects si logique dupliquée

---

**Version :** 2.0
**Source :** Sessions 1-6 kaizen (Simpliscore tunnel_id)
**Status :** Production-ready, 10 patterns validés empiriquement

