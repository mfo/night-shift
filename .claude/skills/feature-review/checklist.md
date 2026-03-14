# Checklist : Review Feature (Phase 3)

**Version :** 2.0
**Temps estimé :** 1-3h (selon complexité)
**Slash command :** `/review`

---

## 🎯 Vue d'Ensemble Phase 3

**Objectif :** Review structurée post-implémentation pour identifier dead code, tests cassés, logique mal placée

**Input :** Feature implémentée (Phase 2 terminée, tests verts)

**Output :**
- `review-<feature>.md` (document review structuré)
- Tous bloquants fixés
- PR mergeable

**Critères gravité :**
- 🔴 **Bloquants** : DOIT être fixé avant merge
- 🟠 **Importants** : Fortement recommandé
- 🟡 **Nice-to-have** : Peut être fait après merge

---

## ✅ Checklist Review Initiale (30-60min)

### Créer Document Review

- [ ] **Document `review-<feature>.md` créé** avec sections :
  - État AVANT vs APRÈS
  - ✅ Points positifs (le bon)
  - ⚠️ Points à améliorer (le mauvais)
  - 🔴 Points critiques (l'horrible)
  - Checklist de fixes priorisée

### Lire Tous Commits PR

- [ ] Tous commits lus attentivement
- [ ] Ordre commits vérifié (logique ?)
- [ ] Messages commits vérifiés (clairs ?)
- [ ] Breaking changes identifiés

### Identifier Points par Gravité

- [ ] **🔴 Bloquants** identifiés
  - Dead code qui casse tests
  - Tests système cassés
  - Violations linters (Rubocop)
  - Sécurité (validations manquantes)

- [ ] **🟠 Importants** identifiés
  - Logique métier mal placée (Component → Query)
  - N+1 queries non documentées
  - Memoization inappropriée
  - Code dupliqué (> 3 fois)

- [ ] **🟡 Nice-to-have** identifiés
  - Helpers pour DRY
  - Tests edge cases
  - Documentation inline

**Checkpoint :**
- Document review créé ?
- Points catégorisés par gravité ?

---

## 🔍 Checklist Patterns à Chercher

### Dead Code

- [ ] **Fichiers supprimés mais référencés ?**
  ```bash
  # Chercher références à code supprimé
  grep -r "OldServiceName" app/ spec/
  grep -r "TunnelFinder" app/ spec/
  ```

- [ ] **Imports inutilisés ?**
  ```bash
  # Rubocop détecte certains
  bundle exec rubocop --only Lint/UselessAssignment
  ```

---

### Tests Cassés

- [ ] **Tests système adaptés ?**
  - Comportement changé (ex: auto-enchainement)
  - Tests assume ancien comportement
  - Utiliser `find_by!` au lieu de `create` si entité auto-créée

- [ ] **Tests isolation correcte ?**
  - Setup context pour before_actions
  - Params matchent setup

---

### Logique Métier Mal Placée

- [ ] **Logique dans ViewComponent ?**
  ```ruby
  # ❌ Component avec logique métier
  class AiComponent
    def any_tunnel_finished?
      procedure.llm_rule_suggestions.exists?(...)
    end
  end
  ```

  **Solution :** Déplacer vers Query Object

- [ ] **Logique dans Controller ?**
  - Extraction vers Service/Query si > 10 lignes

---

### N+1 Queries

- [ ] **N+1 identifiées mais non documentées ?**
  ```bash
  # Lancer avec bullet gem en dev
  BULLET=true rails server
  # Tester feature
  # Vérifier logs bullet
  ```

  **Si N+1 détectée :**
  - Documenter trade-off dans spec (si acceptable)
  - OU optimiser avec `includes`

---

### Validations / Index DB

- [ ] **Validation uniqueness sans index DB ?**
  ```bash
  grep "validates.*uniqueness" app/models/
  # Pour chaque validation uniqueness :
  grep -r "add_index.*unique: true" db/migrate/
  ```

  **Vérifier cohérence scope ↔ index**

---

## 🔴 Checklist Fixes Bloquants (Tous obligatoires)

**Ordre de traitement :**

### 1. Dead Code Cassant Tests

- [ ] Identifier fichiers/méthodes supprimés mais référencés
- [ ] Supprimer références OU corriger imports
- [ ] Vérifier tests passent après fix
  ```bash
  bundle exec rspec
  ```

**Temps estimé :** 10-20min

---

### 2. Tests Système Cassés

- [ ] Adapter tests au nouveau comportement
  ```ruby
  # Pattern adaptation auto-enchainement
  scenario 'workflow avec auto-enchainement' do
    click_button "Accepter"
    # Suggestion suivante auto-créée
    suggestion = LLMRuleSuggestion.find_by!(...)
    expect(suggestion).to be_present
  end
  ```

- [ ] Vérifier redirections finales
- [ ] Tester extraction données URL

**Temps estimé :** 20-40min

---

### 3. Violations Linters (Rubocop)

- [ ] Lancer Rubocop
  ```bash
  bundle exec rubocop
  ```

- [ ] Corriger toutes offenses
  ```bash
  bundle exec rubocop -a  # Auto-correct safe
  # Corriger manuellement reste
  ```

**Temps estimé :** 15-30min

---

### 4. Sécurité (Validations Manquantes)

- [ ] Vérifier validations critiques présentes
  - `presence: true` sur champs obligatoires
  - `format: { with: /.../ }` sur formats stricts
  - `uniqueness: { scope: [...] }` avec index DB

- [ ] Vérifier authorization
  - Policy Pundit présente ?
  - Tests authorization passent ?

**Temps estimé :** 10-20min

---

**Checkpoint Bloquants :**
- [ ] Tous bloquants résolus (🔴 = 0) ?
- [ ] Tests passent (0 failures) ?
- [ ] Rubocop clean (0 offenses) ?

---

## 🟠 Checklist Fixes Importants (Fortement recommandé)

### 1. Logique Métier → Query/Service

- [ ] Identifier logique dans Component/Controller
- [ ] Créer Query Object approprié
- [ ] Déplacer logique + tests
- [ ] Component/Controller juste délègue

**Pattern pré-approuvé :**
```ruby
# app/queries/llm/tunnel_finished_query.rb
class LLM::TunnelFinishedQuery
  def self.any_finished?(revision_id)
    LLMRuleSuggestion.exists?(...)
  end
end

# Component délègue
class AiComponent
  def any_tunnel_finished?
    TunnelFinishedQuery.any_finished?(procedure.draft_revision.id)
  end
end
```

**Temps estimé :** 20-30min

---

### 2. N+1 Queries

- [ ] **Option A : Documenter trade-off** (si N petit, acceptable)
  - Ajouter section dans spec
  - Rationale : volume, fréquence, simplicité

- [ ] **Option B : Optimiser** (si N grand, problématique)
  - Utiliser `includes`
  - Ou query unique avec JOIN
  - Benchmarker amélioration

**Temps estimé :** 30-60min (selon option)

---

### 3. Memoization Inappropriée

- [ ] Identifier memoization dans actions changeant état
- [ ] Supprimer `||=` ou ajouter `force_reload:`
- [ ] Vérifier tests passent

**Temps estimé :** 15-20min

---

### 4. Code Dupliqué (> 3 fois)

- [ ] Identifier patterns répétés
  ```bash
  grep -r "pattern_répété" app/ | wc -l
  # Si >= 3 → extraire
  ```

- [ ] Créer Query Object/Helper
- [ ] Remplacer duplications
- [ ] Tests isolation

**Temps estimé :** 30-45min

---

**Checkpoint Importants :**
- [ ] Tous importants résolus ?
- [ ] OU user a validé backlog ?

---

## 🟡 Checklist Nice-to-Have (Backlog acceptable)

- [ ] **Helpers pour DRY**
  - Créer helper `format_tunnel_id`
  - Utiliser dans views/components

- [ ] **Tests edge cases**
  - Tunnel avec > 100 suggestions
  - Schema change pendant workflow
  - Concurrent access

- [ ] **Documentation inline**
  - Commenta ires sur logique complexe
  - YARD docs sur méthodes publiques

**Temps estimé :** 60-90min total

**Décision :** User décide si faire maintenant ou backlog

---

## 🔧 Checklist Git Absorb (15min)

**Après tous fixes appliqués :**

- [ ] **Git add par hunk**
  ```bash
  git add -p
  # Sélectionner changes une par une
  ```

- [ ] **Git absorb**
  ```bash
  git absorb
  # Absorbe automatiquement dans commits existants
  ```

- [ ] **Si commits trop fragmentés, squash**
  ```bash
  git rebase -i HEAD~N --autosquash
  # Fusionner fixups dans commits principaux
  ```

**Bénéfices :**
- Historique clean (fixes intégrés)
- Pas de commits "fix typo"
- Review plus facile

**Checkpoint :**
- [ ] Historique clean ?
- [ ] Commits logiques et atomiques ?

---

## ✅ Checklist Validation Finale

**Avant de marquer PR mergeable :**

- [ ] **Tous bloquants résolus** (🔴 = 0)
- [ ] **Tous importants résolus** OU documentés en backlog
- [ ] **Tests passent** (0 failures)
  ```bash
  bundle exec rspec
  # X examples, 0 failures ✅
  ```

- [ ] **Rubocop clean** (0 offenses)
  ```bash
  bundle exec rubocop
  # 0 offenses ✅
  ```

- [ ] **Coverage ≥ 80%**
  ```bash
  COVERAGE=true bundle exec rspec
  ```

- [ ] **PR description mise à jour**
  - Breaking changes documentés
  - Fixes appliqués listés
  - Context métier clair

- [ ] **Document review complet**
  - `review-<feature>.md` créé
  - Toutes sections remplies
  - Décisions documentées

**Checkpoint final Phase 3 :**
- [ ] **PR MERGEABLE** ?

---

## 📊 Métriques de Succès

**Phase 3 réussie si :**
- [ ] Document review créé
- [ ] Bloquants fixés (🔴 = 0)
- [ ] Importants fixés (🟠 = 0 ou backlog documenté)
- [ ] Git absorb effectué
- [ ] PR mergeable

**Temps total Phase 3 :** 1-3h
- Review initiale : 30-60min
- Fixes bloquants : 30-90min
- Fixes importants : 30-90min
- Git absorb : 15min

**Score autonomie :** 7/10 (décisions user pour trade-offs)

---

## ⚠️ Pièges à Éviter

### 1. Skip Bloquants
**Problème :** Merger avec dead code ou tests cassés
**Impact :** Production crash, régression
**Solution :** Tous bloquants DOIVENT être fixés

### 2. Fixes Sans Tests
**Problème :** Corriger code sans vérifier tests passent
**Impact :** Nouvelle régression introduite
**Solution :** Lancer tests après chaque fix

### 3. Commits "fix typo" Multiples
**Problème :** Historique pollué avec 10 commits fixup
**Impact :** Review difficile, git log illisible
**Solution :** Git absorb pour intégrer fixes

---

## 🔗 Références

**Template :** `template.md` (dans ce dossier)
**Input :** Feature implémentée (Phase 2)
**Patterns :** `../feature-implementation/patterns.md`
**Methodology :** `pocs/4-features/setup.md`

---

**Version :** 2.0
**Source :** Sessions 1-6 kaizen (Simpliscore tunnel_id)
**Status :** Production-ready

