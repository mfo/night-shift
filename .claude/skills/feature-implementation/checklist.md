# Checklist : Implement Feature (Phase 2)

**Version :** 2.0
**Temps estimé :** 8-20h (selon complexité)
**Slash command :** `/implement` ou exécution manuelle

---

## 🎯 Vue d'Ensemble Phase 2

**Objectif :** Exécuter le plan d'implémentation commit par commit avec tests verts à chaque étape

**Input :** `specs/YYYY-MM-DD-[nom]-implementation-plan.md` (COMMIT_PLAN.md validé)

**Output :** Feature implémentée (N commits, tests verts, prêt pour review)

**Principes CRITIQUES :**
1. ⚠️ Tests verts à chaque commit (PRIORITÉ ABSOLUE)
2. Commits atomiques par nature de changement
3. Ordre logique de dépendances respecté
4. Breaking changes en blocs documentés

---

## ✅ Checklist Pré-Commit (POUR CHAQUE COMMIT)

**Avant de commiter, vérifier SYSTÉMATIQUEMENT :**

- [ ] **Code compile ?** (pas d'erreur syntax)
  ```bash
  # Rails console doit démarrer
  rails console
  ```

- [ ] **Tests passent ?** ⚠️ CRITIQUE
  ```bash
  bundle exec rspec
  ```
  - Si **OUI** → ✅ Continuer
  - Si **NON** → ⚠️ Raison documentée dans commit message avec `⚠️ TESTS BROKEN`

- [ ] **Rubocop propre ?**
  ```bash
  bundle exec rubocop [fichiers modifiés]
  ```

- [ ] **Specs mises à jour ?**
  - Si code change → specs aussi (même commit)
  - Pattern : Interleave code + specs

**Exception autorisée :**
- Breaking change atomique documenté
- Commit message DOIT contenir :
  ```
  ⚠️ TESTS BROKEN: [raison]
  Fix in commits X-Y (N call-sites to update)
  ```

---

## 🎯 Checklist Patterns Critiques

**À appliquer SYSTÉMATIQUEMENT pendant implémentation :**

### Pattern 1 : State Checks Explicites

- [ ] **Utiliser `.state&.in?([...])`** au lieu de boolean combinations

**❌ ÉVITER :**
```ruby
return if record&.persisted? && !record&.failed?
```

**✅ PRÉFÉRER :**
```ruby
return if record&.state&.in?(['queued', 'running'])
```

---

### Pattern 2 : Pas de Memoization Inappropriée

- [ ] **Éviter memoization** dans controller actions modifiant état DB

**❌ ÉVITER :**
```ruby
def current_schema_hash
  @current_schema_hash ||= calculate_hash(draft.schema)
  # ⚠️ Valeur stale si draft modifié pendant action
end
```

**✅ PRÉFÉRER :**
```ruby
def current_schema_hash
  calculate_hash(draft.reload.schema)
end
```

---

### Pattern 3 : Self-Documenting Variables

- [ ] **Si nesting > 2 niveaux** → variables auto-documentées

**✅ Appliquer :**
```ruby
# Variables explicites
current_step_finished = condition1
last_completed_step = query.method if current_step_finished
next_rule = logic(last_completed_step) if last_completed_step

# Structure if/elsif/else unique
if next_rule
  action1
elsif other_condition
  action2
else
  default
end
```

**Impact attendu :** -40-50% lignes, -75% nesting

---

### Pattern 4 : Tests Isolation

- [ ] **Setup context** pour before_actions

**✅ Tests controller avec before_action :**
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

it 'renders view' do
  get :action, params: { tunnel_id:, rule: 'improve_label' }
  expect(response).to be_successful
end
```

---

### Pattern 5 : Checkpoint Validation Uniqueness

- [ ] **Vérifier cohérence** validation Rails ↔ Index DB

**Quand tu ajoutes/modifies :**
```ruby
validates :field, uniqueness: { scope: [:field_a, :field_b] }
```

**Checklist :**
1. Chercher index unique correspondant :
   ```bash
   grep -r "add_index.*unique: true" db/migrate/
   cat db/schema.rb | grep -A3 "unique: true"
   ```

2. Vérifier cohérence :
   - Validation scope: `[:field_a, :field_b, :field_c]`
   - Index DB: `add_index :table, [:field_a, :field_b, :field_c], unique: true`

3. Si incohérence → migration pour corriger

---

## 📊 Checklist Mi-Phase (Après ~50% commits)

**Checkpoint intermédiaire (~4-10h après début) :**

- [ ] Tests verts maintenus jusqu'ici ?
  ```bash
  bundle exec rspec
  # 0 failures attendu
  ```

- [ ] Breaking changes documentés en commit messages ?
  - Vérifier commits avec `(BREAKING)` dans titre
  - Vérifier `⚠️ TESTS BROKEN` documenté

- [ ] Patterns critiques appliqués ?
  - State checks explicites
  - Pas memoization inappropriée
  - Self-documenting si nesting > 2

- [ ] Rubocop propre ?
  ```bash
  bundle exec rubocop
  # 0 offenses attendu
  ```

- [ ] Aucun blocage > 30min ?
  - Si blocage → STOP et demander aide user

**Si problème détecté :**
- STOP implémentation
- Documenter où tu bloques
- Demander aide user

---

## ✅ Checklist Fin Phase 2

**Validation finale avant de passer à Phase 3 :**

- [ ] **Tous commits exécutés** selon plan
  - Comparer nombre commits plan vs. réels

- [ ] **Suite complète tests passe**
  ```bash
  bundle exec rspec
  # X examples, 0 failures ✅
  ```

- [ ] **Rubocop clean**
  ```bash
  bundle exec rubocop
  # 0 offenses ✅
  ```

- [ ] **Coverage ≥ 80%**
  ```bash
  COVERAGE=true bundle exec rspec
  # Vérifier coverage report
  ```

- [ ] **Breaking changes en blocs**
  - Si breaking changes → commits groupés (merge safe)

- [ ] **Feature implémentée complètement**
  - Tous objectifs spec atteints
  - Toutes acceptance criteria validées

**Checkpoint final Phase 2 :**
- [ ] Prêt pour Phase 3 (Review & Cleanup) ?

---

## ⚠️ Pièges Critiques à Éviter

### 1. Tests Cassés Commits 4-15 ❌

**Problème :** Approche "code first, tests later"
- Commits 4-14 : Code changes (⚠️ tests rouges)
- Commits 15-16 : Fix all tests

**Impact :**
- Git bisect cassé
- Historique illisible
- Reviewers confus

**Solution :** ✅ Interleave code + specs chaque commit

---

### 2. Boolean Combinations pour State ❌

**Problème :**
```ruby
return if record&.persisted? && !record&.failed?
```

**Impact :**
- Fragile (nouveaux états cassent logique)
- Intention pas claire
- Bugs edge cases

**Solution :** ✅ State checks explicites
```ruby
return if record&.state&.in?(['queued', 'running'])
```

---

### 3. Memoization dans Actions Changeant État ❌

**Problème :**
```ruby
def current_schema_hash
  @current_schema_hash ||= calculate(draft.schema)
  # ⚠️ Stale après draft.update!
end
```

**Impact :**
- Valeurs stales
- Bugs subtils
- Tests passent mais prod crash

**Solution :** ✅ Recalculer à chaque appel

---

### 4. Tests Sans Setup Context ❌

**Problème :**
```ruby
it 'renders view' do
  get :action, params: { tunnel_id: 'abc123' }
  # ❌ Échoue : before_action redirige (pas de context)
end
```

**Impact :** 18+ tests failures mystérieuses

**Solution :** ✅ Setup context complet (Pattern 4)

---

### 5. Validation Rails Sans Index DB ❌

**Problème :**
```ruby
validates :x, uniqueness: { scope: [:a, :b] }
# Mais pas d'index unique en DB
```

**Impact :**
- Tests passent (SQLite permissive)
- Prod crashe (PostgreSQL strict)

**Solution :** ✅ Checkpoint validation uniqueness (Pattern 5)

---

## 🔧 Commandes Utiles

### Exécuter Tests
```bash
# Suite complète
bundle exec rspec

# Tests spécifiques
bundle exec rspec spec/models/
bundle exec rspec spec/controllers/
bundle exec rspec spec/system/

# Fichier spécifique
bundle exec rspec spec/models/model_spec.rb

# Test spécifique
bundle exec rspec spec/models/model_spec.rb:42
```

### Vérifier Qualité Code
```bash
# Rubocop
bundle exec rubocop
bundle exec rubocop -a  # Auto-correct

# Coverage
COVERAGE=true bundle exec rspec

# Strong Migrations
bundle exec rails db:migrate
# Vérifie safe migrations
```

### Debug
```bash
# Rails console
rails console

# Logs
tail -f log/development.log

# DB console
rails dbconsole
```

---

## 📊 Métriques de Succès

**Phase 2 réussie si :**
- [ ] Tous commits tests verts (sauf exception documentée)
- [ ] State checks explicites appliqués
- [ ] Pas memoization inappropriée
- [ ] Tests isolation correcte
- [ ] Validation uniqueness cohérente
- [ ] Self-documenting variables (nesting < 2)
- [ ] Rubocop clean (0 offenses)
- [ ] Coverage ≥ 80%

**Temps total Phase 2 :** 8-20h (selon complexité)
- Phase 1 (DB) : 1-2h
- Phase 2 (Infra) : 1-2h
- Phase 3 (Features) : 2-4h
- Phase 4 (UI) : 1-2h
- Phase 5 (Tests) : 2-4h
- Phase 6 (Cleanup) : 0.5-1h
- Phase 7 (UX optionnel) : 0.5-1h

**Score autonomie :** 7/10

---

## 🔗 Références

**Input :** COMMIT_PLAN.md validé
**Patterns :** `patterns.md` (dans ce dossier, 10 patterns détaillés)
**Methodology :** `pocs/4-features/setup.md`
**Prochaine phase :** `../feature-review/checklist.md`

---

**Version :** 2.0
**Source :** Sessions 1-6 kaizen (Simpliscore tunnel_id)
**Status :** Stabilisé (testé sur 1 feature, N=1)

