# POC 4 : Features Complexes - Setup & Méthodologie

**Objectif :** Workflow complet 4 phases pour features complexes (spec → plan → implémentation → review)
**Version :** 2.0 (enrichi avec learnings sessions 1-6)

---

## 📚 Documentation Complète

**Ce POC dispose d'une documentation complète enrichie par les learnings des sessions 1-6 :**

### Documents Principaux

1. **[feature-implementation-patterns.md](feature-implementation-patterns.md)** - Catalogue patterns agent-friendly ⭐
   - 10 patterns validés empiriquement (score 8-10/10)
   - Exemples concrets avec code
   - Rationale et impact mesurés

2. **Checklists par phase** ⭐
   - [feature-spec-checklist.md](feature-spec-checklist.md) - Phase 0
   - [feature-plan-checklist.md](feature-plan-checklist.md) - Phase 1
   - [feature-implementation-checklist.md](feature-implementation-checklist.md) - Phase 2
   - [feature-review-checklist.md](feature-review-checklist.md) - Phase 3

### Templates

3. **[feature-spec-template.md](feature-spec-template.md)** - Template spec technique (15 sections)
4. **[feature-plan-template.md](feature-plan-template.md)** - Template plan atomique
5. **[feature-review-template.md](feature-review-template.md)** - Template review post-implémentation

### Kaizen Iteration 1

6. **[iteration-1/](iteration-1/)** - 8 sessions Simpliscore
   - session-1-simpliscore-implementation.md
   - session-2-simpliscore-implementation.md
   - kaizen-schema-change-detection.md
   - kaizen-git-history-reconstruction.md
   - session-5-review-cleanup.md
   - kaizen-self-documenting-variables.md
   - kaizen-spec-creation.md
   - kaizen-plan-creation.md
   - simpliscore-tunnel-id-results.md

---

## 📐 Méthodologie : Workflow Complet 4 Phases

### 🎯 Vue d'Ensemble

**Contexte :** Implémentation de features complexes (refactorings architecturaux, migrations DB, workflows multi-composants)

**Objectif :** Workflow agent-friendly en 4 phases pour passer d'un problème/besoin à une feature mergeable

**Score autonomie visé :** 7-9/10 selon phase (auto-évalué)

---

### Workflow Complet

```
Phase 0: Create-Spec (4-8h)
  ├─ Analyse problème + architecture existante
  ├─ Conception architecture (décisions avec user)
  ├─ Rédaction spec v1 (15 sections)
  ├─ Review agent PM (obligatoire si > 500 lignes)
  └─ Itérations user → Spec validée
      ↓
Phase 1: Create-Plan (1-2h)
  ├─ Lecture spec complète
  ├─ Découpage commits atomiques (< 20)
  ├─ Organisation en phases logiques (7 phases)
  ├─ Isolation breaking changes
  └─ Validation user → COMMIT_PLAN.md
      ↓
Phase 2: Implementation (8-20h)
  ├─ Exécution commit par commit
  ├─ Tests verts à chaque commit ⚠️ CRITIQUE
  ├─ Breaking changes en bloc
  └─ Tous tests passent → Feature implémentée
      ↓
Phase 3: Review & Cleanup (1-3h)
  ├─ Review structurée (`review-<feature>.md`)
  ├─ Fixes bloquants (dead code, tests cassés)
  ├─ Fixes importants (logique mal placée, N+1)
  └─ Git absorb + autosquash → PR mergeable
```

---

## Phase 0 : Create-Spec (4-8h)

### Objectif
Créer une spécification technique validée documentant toutes les décisions d'architecture.

### Quand utiliser ?
- ✅ Bug architectural (nécessite refactoring global)
- ✅ Feature complexe avec décisions d'architecture
- ✅ Refactoring > 5 fichiers impactés
- ❌ Fix simple (< 3 fichiers, pas de décision métier)

### Workflow détaillé

#### 1. Analyse Problème (30min)
**Actions :**
- Lire code existant (fichiers impactés)
- Comprendre architecture actuelle
- Identifier root cause (si bug) ou besoin (si feature)
- Grep patterns critiques (call-sites, duplications)

**Commandes utiles :**
```bash
# Trouver call-sites
grep -r "ClassName\|method_name" app/ lib/ spec/

# Trouver duplications
grep -r "pattern_répété" app/

# Identifier tests existants
find spec -name "*nom_fichier*_spec.rb"
```

**Checkpoint :**
- [ ] Problème compris ?
- [ ] Architecture existante claire ?
- Si NON → Demander clarifications au user

---

#### 2. Conception Architecture (1-2h)

**Questions à poser au user :**
- Format des identifiants ? (UUID, hex, int)
- Trade-off performance vs. simplicité ?
- Breaking changes acceptables ?
- Auto-lancement ou contrôle user ?
- Validation stricte ou permissive ?

**Patterns à détecter proactivement :**
1. **Logique répétée 3+ fois** → Proposer Query Object
2. **N+1 queries** → Documenter trade-off (optimiser vs. simplicité)
3. **Breaking changes** → Lister call-sites impactés
4. **Index DB manquants** → Proposer ajout pour perf
5. **Conditions imbriquées > 2 niveaux** → Proposer self-documenting variables

**Checkpoint :**
- [ ] Architecture conçue ?
- [ ] Décisions prises avec user ?
- [ ] Patterns DRY identifiés ?

---

#### 3. Rédaction Spec v1 (1-2h)

**Structure obligatoire (15 sections minimum) :**

```markdown
# Spec Technique : [Titre]

## 1. Contexte & Problème
[Description + root cause + objectifs]

## 2. Décisions d'Architecture
[Chaque décision : Choix + Alternative + Rationale + Impact]

## 3. Architecture Proposée
[Vue d'ensemble + composants impactés]

## 4. Modèle (Database & ActiveRecord)
[Migrations + Validations + Index]

## 5. Controller
[Routes + Actions]

## 6. Jobs
[Signature + Call-sites impactés si BREAKING]

## 7. Services / Query Objects
[Extraction DRY si logique répétée 3+]

## 8. Tests
[Tests à créer + Tests à modifier]

## 9. Migration de Données (Backfill)
[Strategy + Rollback plan]

## 10. Breaking Changes
[Liste avec call-sites + Plan migration]

## 11. Performance
[N+1 identifiées + Index + Trade-offs documentés]

## 12. Sécurité
[Validations + Authorization]

## 13. UX / Product
[Comportement attendu + Edge cases]

## 14. Rollout Strategy
[Phases de déploiement]

## 15. Métriques & Monitoring
[Métriques à tracker + Alertes]
```

**Checkpoint :**
- [ ] 15 sections complètes ?
- [ ] Breaking changes documentés ?
- [ ] Trade-offs justifiés ?

---

#### 4. Review Agent PM (45min-1h)

**⚠️ OBLIGATOIRE pour specs > 500 lignes**

**Actions :**
1. Lancer agent PM Senior pour review
2. Analyser findings (10-20 problèmes attendus)
3. Corriger par gravité :
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

**Checkpoint :**
- [ ] Review findings analysés ?
- [ ] Problèmes critiques corrigés ?
- [ ] Spec v2 validée ?

---

#### 5. User Review + Décisions (1-2h)

**Présenter au user :**
- Spec v2 (post-review PM)
- Décisions d'architecture à trancher
- Estimation temps implémentation

**Itérations attendues :** Max 8 rounds

**Checkpoint final :**
- [ ] User approuve l'architecture ?
- [ ] Breaking changes acceptés ?
- [ ] Trade-offs validés ?
- [ ] Estimation temps réaliste ?

---

### Livrables Phase 0
- `specs/YYYY-MM-DD-[nom]-spec.md` (spec finale)
- `specs/YYYY-MM-DD-[nom]-review-v1.md` (review PM)
- `specs/YYYY-MM-DD-[nom]-review-v2.md` (validation finale)

**Temps total Phase 0 :** 4-8h
**Score autonomie :** 7/10 seul, 9/10 avec review PM

---

## Phase 1 : Create-Plan (1-2h)

### Objectif
Transformer spec validée en plan d'implémentation exécutable avec commits atomiques.

### Workflow détaillé

#### 1. Lecture Spec Complète (20-30min)
**Actions :**
- Comprendre tous les composants impactés
- Identifier dépendances entre changements
- Repérer breaking changes

---

#### 2. Découpage Commits Atomiques (1h)

**Principes critiques :**
- **1 commit = 1 concept isolé et testable**
- **Max 5 fichiers par commit** (idéal : 1-3)
- **Max 20 commits total** (sinon revoir découpage)

**Ordre logique (7 phases standards) :**

```markdown
Phase 1: Database (migrations, backfill, constraints)
Phase 2: Infrastructure (models, validations, query objects)
Phase 3: Features (routes, controllers, jobs)
Phase 4: UI (components, views)
Phase 5: Tests (system, unit)
Phase 6: Cleanup (suppression code mort)
Phase 7: UX (améliorations cosmétiques, wording)
```

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
→ Merge en bloc obligatoire, documenter plage commits

**Pattern 3 : Tests Séparés**
```
Commit N-1: tests: update system specs
Commit N: tests: update unit specs
```
→ Features reviewables sans bruit tests

**Pattern 4 : Tests Verts à Chaque Commit ⚠️ CRITIQUE**
```
✅ BON :
Commit 4: model: add validations + update factory/specs
Commit 5: query: create TunnelFinishedQuery + specs

❌ MAUVAIS :
Commits 4-14: code changes
Commits 15-16: fix all tests
```
→ Git bisect fonctionnel, historique lisible

---

#### 3. Documentation Commits (20-30min)

**Template commit standardisé :**
```markdown
### ✅ Commit X: `scope: one-line description`

**Objectif :** [1 phrase explicite]

**Fichiers à modifier :**
- [ ] `path/to/file.rb` (add method X)
- [ ] `path/to/spec.rb` (test method X)

**Actions :**
[Code exact ou instructions précises]

**Tests à exécuter :**
- [ ] `bundle exec rspec path/spec.rb`

**Notes :**
- ⚠️ BREAKING CHANGE si applicable
- Code cassé entre commits X-Y
```

---

#### 4. Présentation User (10min)

**Présenter :**
- Nombre total commits (< 20 idéal)
- Phases identifiées (7 phases standard)
- Breaking changes (plage commits impactés)
- Estimation temps (commits × 30-60min)
- Tableau récapitulatif

**Checkpoint :**
- [ ] Commits atomiques définis ?
- [ ] Max 20 commits ?
- [ ] Phases logiques respectées ?
- [ ] Breaking changes isolés ?
- [ ] Tests exécutables après chaque commit ?
- [ ] User approuve structure ?

---

### Livrables Phase 1
- `specs/YYYY-MM-DD-[nom]-implementation-plan.md` (COMMIT_PLAN.md)

**Temps total Phase 1 :** 1-2h
**Score autonomie :** 8/10

---

## Phase 2 : Implementation (8-20h)

### Objectif
Exécuter le plan d'implémentation commit par commit avec tests verts à chaque étape.

### Principes CRITIQUES

#### 1. Tests Verts à Chaque Commit ⚠️ PRIORITÉ ABSOLUE

**Règle :**
Chaque commit doit avoir tests passants, sauf exception documentée.

**Approche :**
```ruby
# ✅ CORRECT : Interleave code + specs
Commit N: Code change + spec update
Commit N+1: Code change + spec update
```

**Exception autorisée :**
Breaking change atomique où tests DOIVENT être cassés → documenter explicitement dans commit message :
```
⚠️ TESTS BROKEN: [raison] + plan fix commits X-Y
```

**Pourquoi critique :**
- Git bisect fonctionnel
- Historique lisible pour reviewers
- Confiance à chaque étape
- Debug facilité (problème identifié immédiatement)

---

#### 2. State Checks Explicites

**Pattern :**
```ruby
# ❌ ÉVITER : Boolean combinations
return if record&.persisted? && !record&.failed?

# ✅ PRÉFÉRER : State explicite
return if record&.state&.in?(['queued', 'running'])
```

**Rationale :**
- Intention claire
- Facile à maintenir (ajout nouveaux états)
- Moins de bugs (edge cases évidents)

---

#### 3. Éviter Memoization dans Controller Actions

**Pattern :**
```ruby
# ❌ INTERDIT : Memoization si état DB change mid-action
def current_schema_hash
  @current_schema_hash ||= calculate_hash(draft.schema)
  # ⚠️ Si draft modifié → retourne valeur stale
end

# ✅ PRÉFÉRER : Recalcule à chaque appel
def current_schema_hash
  calculate_hash(draft.reload.schema)
end
```

**Exception :** Si vraiment besoin perf → pattern `force_reload:` explicite

---

#### 4. Self-Documenting Variables pour Réduire Nesting

**Pattern :**
```ruby
# ❌ AVANT : 4 niveaux nesting
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

# ✅ APRÈS : 1 niveau nesting, variables auto-documentées
current_step_finished = current_suggestion&.state&.in?(['accepted', 'skipped'])
last_completed_step = query.last_completed_step if current_step_finished
next_rule = LLM::Rule.next_rule(last_completed_step.rule) if last_completed_step
visiting_different_step = last_completed_step && params[:rule] != last_completed_step.rule

if next_rule
  redirect_to path(rule: next_rule)
elsif visiting_different_step
  redirect_to path(rule: last_completed_step.rule)
else
  # default case
end
```

**Impact mesuré :**
- Réduction 33→18 lignes (-45%)
- Réduction 4→1 nesting (-75%)
- Lisibilité grandement améliorée

---

#### 5. Tests Isolation avec Before Actions

**Pattern :**
```ruby
# ❌ TEST QUI ÉCHOUE : Pas de context setup
describe '#simplify' do
  it 'renders simplify view' do
    get :simplify, params: { tunnel_id: 'abc123', rule: 'improve_label' }
    # ❌ Échoue : ensure_valid_tunnel redirige (aucune suggestion en DB)
  end
end

# ✅ TEST CORRECT : Context établi
describe '#simplify' do
  let(:tunnel_id) { SecureRandom.hex(3) }

  before do
    # Créer contexte nécessaire pour passer before_action
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

---

#### 6. Checkpoint Validation Uniqueness

**Quand tu ajoutes/modifies `validates :field, uniqueness: { scope: [...] }` :**

1. ✅ Cherche index unique correspondant en DB :
   ```bash
   grep -r "add_index.*unique: true" db/migrate/
   cat db/schema.rb | grep -A3 "unique: true"
   ```

2. ✅ Vérifie cohérence :
   - Validation Rails scope: `[:field_a, :field_b, :field_c]`
   - Index DB: `add_index :table, [:field_a, :field_b, :field_c], unique: true`

3. ⚠️ Si incohérence → créer migration pour :
   - Supprimer ancien index unique (si exists)
   - Ajouter nouveau index unique cohérent

**Pourquoi :** Tests passent avec validation Rails seule, mais production crashe si DB rejette (PG::UniqueViolation)

---

### Workflow Exécution

**Pour chaque commit du plan :**

1. **Lire description commit** (objectif, fichiers, actions)
2. **Exécuter actions** (code changes)
3. **Lancer tests** (`bundle exec rspec`)
4. **Vérifier tests verts** ✅ ou documenter raison si rouges
5. **Commit** avec message conventionnel
6. **Update TodoWrite** (marquer completed)

**Si blocage > 30min :**
- STOP et demander aide user
- Documenter où tu bloques
- Proposer alternative si possible

---

### Livrables Phase 2
- Feature implémentée (17 commits typiques)
- Tous tests verts ✅
- Rubocop clean
- Prêt pour review

**Temps total Phase 2 :** 8-20h selon complexité
**Score autonomie :** 7/10

---

## Phase 3 : Review & Cleanup (1-3h)

### Objectif
Review structurée post-implémentation pour identifier dead code, tests cassés, logique mal placée.

### Workflow détaillé

#### 1. Review Structurée (30-60min)

**Agent crée document `review-<feature>.md` :**
```markdown
# Review : [Feature]

## État AVANT vs APRÈS
[Comparaison architecture]

## ✅ Points Positifs (Le Bon)
- [Liste]

## ⚠️ Points à Améliorer (Le Mauvais)
- [Liste avec gravité : Bloquant / Important / Nice-to-have]

## 🔴 Points Critiques (L'Horrible)
- [Bloquants avant merge]

## Checklist Fixes
- [ ] Bloquant 1 : Dead code cassant tests
- [ ] Bloquant 2 : Tests système cassés
- [ ] Important 1 : Logique métier mal placée
- [ ] Nice-to-have 1 : Helper pour DRY
```

---

#### 2. Fixes par Priorité (30-90min)

**Ordre obligatoire :**

**🔴 Bloquants (avant merge) :**
- Dead code qui casse les tests
- Tests système cassés
- Violations linters
- Sécurité (validations manquantes)

**🟠 Importants (fortement recommandé) :**
- Logique métier mal placée (Component → Query)
- N+1 queries identifiées
- Memoization inappropriée

**🟡 Nice to have (après merge) :**
- Helpers pour DRY
- Tests edge cases
- Documentation

---

#### 3. Pattern : Adaptation Tests Système

**Si feature change comportement (ex: auto-enchainement) :**

```ruby
# ❌ AVANT : Test assume ancien comportement
scenario 'workflow manuel' do
  click_button "Lancer recherche"
  # Attend état "recherche en cours"
  suggestion = create(:suggestion, ...) # Créé manuellement
end

# ✅ APRÈS : Test adapté au nouveau comportement
scenario 'workflow avec auto-enchainement' do
  click_button "Accepter"
  # La suggestion suivante est créée automatiquement
  suggestion_suivante = LLMRuleSuggestion.find_by!(...)
  expect(suggestion_suivante).to be_present
end
```

**Pré-approuvé :**
- Adapter tests au nouveau comportement (pas juste skip)
- Utiliser `find_by!` pour entités auto-créées
- Tester redirection finale

---

#### 4. Pattern : Déplacement Logique Métier

**Si logique dans ViewComponent :**

```ruby
# ❌ Component avec logique métier
class AiComponent
  def any_tunnel_finished?
    procedure.llm_rule_suggestions
      .exists?(rule: LAST, state: [:accepted, :skipped])
  end
end

# ✅ Déplacé dans Query Object
class TunnelFinishedQuery
  def self.any_finished?(revision_id)
    LLMRuleSuggestion.exists?(
      procedure_revision_id: revision_id,
      rule: LAST,
      state: [:accepted, :skipped]
    )
  end
end

# Component juste délègue
class AiComponent
  def any_tunnel_finished?
    TunnelFinishedQuery.any_finished?(procedure.draft_revision.id)
  end
end
```

**Pré-approuvé :**
- Déplacer logique métier : Component → Query/Service
- Component garde uniquement présentation
- Ajouter tests unitaires au Query Object

---

#### 5. Git Absorb + Autosquash (15min)

**Workflow recommandé :**
```bash
# Après tous les fixes
git add -p  # Sélectionner changes par hunk
git absorb  # Absorbe changes dans commits existants

# Si commits trop fragmentés
git rebase -i HEAD~N --autosquash
# Fusionner fixups dans commits principaux
```

---

### Livrables Phase 3
- `review-<feature>.md` (document review)
- Tous bloquants fixés
- PR mergeable tel quel

**Temps total Phase 3 :** 1-3h
**Score autonomie :** 7/10 (décisions user nécessaires pour trade-offs)

---

## 📊 Métriques Globales

### Temps par Phase

| Phase | Temps | Variabilité |
|-------|-------|-------------|
| Phase 0: Create-Spec | 4-8h | Haute (décisions métier) |
| Phase 1: Create-Plan | 1-2h | Faible |
| Phase 2: Implementation | 8-20h | Très haute (complexité code) |
| Phase 3: Review & Cleanup | 1-3h | Moyenne |
| **TOTAL** | **14-33h** | Haute |

### Autonomie par Phase

| Phase | Score | Facteur Limitant |
|-------|-------|------------------|
| Phase 0 | 7/10 (9/10 avec PM) | Décisions métier user |
| Phase 1 | 8/10 | Estimation temps commits |
| Phase 2 | 7/10 | Bugs techniques, edge cases |
| Phase 3 | 7/10 | Trade-offs (N+1, memoization) |

---

## 🚨 Pièges Critiques à Éviter

### 1. ❌ Tests cassés commits 4-15 (approche "code first, tests later")

**Problème :** 12 commits avec tests rouges → git bisect inutilisable, reviewers confus

**Solution :** ✅ Interleave code + specs à chaque commit

**Impact si raté :** Historique Git moins lisible, temps perdu reconstruction

---

### 2. ❌ Boolean combinations pour state checks

**Problème :** `if record&.persisted? && !record&.failed?` → fragile, intention unclear

**Solution :** ✅ `if record&.state&.in?(['queued', 'running'])`

**Impact si raté :** Bugs conditionnels, edge cases manqués

---

### 3. ❌ Memoization dans controller actions avec état DB changeant

**Problème :** `@current_schema_hash ||= calculate` → valeur stale après changement

**Solution :** ✅ Recalculer à chaque appel ou `force_reload:` explicite

**Impact si raté :** Bugs subtils, tests passent mais prod crash

---

### 4. ❌ Tests sans setup contexte before_actions

**Problème :** Test appelle action sans établir contexte requis par before_action

**Solution :** ✅ Setup complet (let, before, create records nécessaires)

**Impact si raté :** 18 tests échouent mystérieusement

---

### 5. ❌ Incohérence validation Rails vs. index DB

**Problème :** `validates :x, uniqueness: { scope: [:a, :b] }` mais index DB différent

**Solution :** ✅ Checkpoint validation uniqueness systématique

**Impact si raté :** Tests passent, prod crashe (PG::UniqueViolation)

---

## 📚 Checklist Production-Ready

### Phase 0 : Create-Spec
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
- [ ] Review agent PM effectuée (si > 500 lignes)

### Phase 1 : Create-Plan
- [ ] Commits atomiques définis (< 20)
- [ ] Phases logiques respectées (7 phases)
- [ ] Breaking changes isolés en blocs
- [ ] Tests exécutables après chaque commit
- [ ] Tableau récapitulatif créé
- [ ] User approuve structure

### Phase 2 : Implementation
- [ ] Tous commits ont tests verts (sauf exception documentée)
- [ ] State checks explicites (pas boolean combinations)
- [ ] Pas de memoization inappropriée
- [ ] Tests isolation correcte (before_action setup)
- [ ] Validation uniqueness cohérente avec index DB
- [ ] Self-documenting variables (nesting < 2)
- [ ] Rubocop clean
- [ ] Coverage ≥ 80%

### Phase 3 : Review & Cleanup
- [ ] Document review créé
- [ ] Bloquants fixés (dead code, tests cassés)
- [ ] Importants fixés (logique mal placée, N+1)
- [ ] Git absorb + autosquash effectué
- [ ] PR mergeable tel quel

---

## 🎯 Quick Start

**Pour implémenter une feature complexe :**

1. **Lire** cette méthodologie (comprendre workflow)
2. **Phase 0 :** Utiliser `feature-spec-template.md` + `feature-spec-checklist.md`
3. **Phase 1 :** Utiliser `feature-plan-template.md` + `feature-plan-checklist.md`
4. **Phase 2 :** Suivre plan + appliquer `feature-implementation-patterns.md` + `feature-implementation-checklist.md`
5. **Phase 3 :** Utiliser `feature-review-template.md` + `feature-review-checklist.md`

---

## 🔄 Amélioration Continue

**Ce document évolue :**
- Chaque nouvelle session = nouveaux learnings
- Patterns validés → ajoutés ici
- Patterns invalidés → retirés ou ajustés

**Prochaines itérations à tester :**
1. Template automatique COMMIT_PLAN.md
2. Checklist pré-commit hook (tests verts ?)
3. Linter custom pour boolean combinations
4. Generator `rails g feature_spec [nom]`

---

**Version :** 2.0
**Sources :** Sessions 1-6 kaizen (Simpliscore tunnel_id)
**Status :** Stabilisé, testé sur 1 feature (17 commits, 7 phases, 8-15h — N=1)
