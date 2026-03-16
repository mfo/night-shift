# Review Post-Implémentation : [Feature]

**Date :** YYYY-MM-DD
**PR :** #XXXX
**Implémentation :** [Lien vers commits]
**Reviewé par :** Agent Claude + [User]
**Version template :** 2.0 (session 5 learnings)

---

## 🎯 Objectif Review

**Contexte :**
Feature [nom] implémentée sur [N] commits. Review structurée pour identifier :
- 🔴 Bloquants avant merge
- 🟠 Importants (fortement recommandé)
- 🟡 Nice-to-have (après merge)

---

## 📊 État AVANT vs APRÈS

### Architecture AVANT

**Composants principaux :**
- [Décrire architecture avant refactoring]

**Problèmes identifiés :**
- [Bug/limitation 1]
- [Bug/limitation 2]

### Architecture APRÈS

**Composants principaux :**
- [Décrire nouvelle architecture]

**Améliorations :**
- [Amélioration 1]
- [Amélioration 2]

**Trade-offs acceptés :**
- [Trade-off 1 avec rationale]
- [Trade-off 2 avec rationale]

---

## ✅ Points Positifs (Le Bon)

### 1. [Aspect positif 1]
**Description :** [Détails]
**Impact :** [Mesurable si possible]

### 2. [Aspect positif 2]
**Description :** [Détails]
**Impact :** [Mesurable si possible]

**Exemples de points positifs à chercher :**
- Architecture claire et maintenable
- Tests complets et bien structurés
- Code DRY (Query Objects, patterns réutilisables)
- Performance optimisée (indexes, N+1 évités)
- Sécurité renforcée (validations, authorization)
- UX améliorée (workflow fluide, messages clairs)

---

## ⚠️ Points à Améliorer (Le Mauvais)

### Catégorie : Bloquants (avant merge)

#### 🔴 Bloquant 1 : [Titre]

**Problème :**
[Description précise du problème]

**Localisation :**
- Fichier : `path/to/file.rb:123`
- Code concerné :
```ruby
# Code problématique
```

**Impact :**
- Tests cassés : [Nombre]
- Risque production : [ÉLEVÉ / MOYEN / FAIBLE]
- Régression possible : [Oui / Non]

**Solution recommandée :**
```ruby
# Code corrigé
```

**Estimation fix :** [X min]

---

#### 🔴 Bloquant 2 : Dead Code Référencé

**Problème :**
Référence à `TunnelFinder` supprimé dans `AiComponent`

**Localisation :**
- `app/components/llm/ai_component.rb:45`

**Impact :**
- Tests échouent : 3 specs components
- Production crasherait : NameError

**Solution :**
Remplacer par `TunnelFinishedQuery` ou supprimer logique obsolète

**Estimation fix :** 10 min

---

### Catégorie : Importants (fortement recommandé)

#### 🟠 Important 1 : Logique Métier Mal Placée

**Problème :**
Logique métier dans ViewComponent au lieu de Query Object

**Localisation :**
```ruby
# app/components/llm/ai_component.rb
class AiComponent
  def any_tunnel_finished?
    procedure.llm_rule_suggestions
      .exists?(rule: LAST, state: [:accepted, :skipped])
  end
end
```

**Impact :**
- Testabilité réduite (logique liée à component)
- Réutilisabilité impossible (locked dans component)

**Solution recommandée :**
```ruby
# app/queries/llm/tunnel_finished_query.rb
class LLM::TunnelFinishedQuery
  def self.any_finished?(revision_id)
    LLMRuleSuggestion.exists?(
      procedure_revision_id: revision_id,
      rule: LAST,
      state: [:accepted, :skipped]
    )
  end
end

# app/components/llm/ai_component.rb
class AiComponent
  def any_tunnel_finished?
    TunnelFinishedQuery.any_finished?(procedure.draft_revision.id)
  end
end
```

**Bénéfices :**
- Testable isolément
- Réutilisable ailleurs
- Logique centralisée

**Estimation fix :** 20 min

---

#### 🟠 Important 2 : N+1 Query Non Documentée

**Problème :**
N+1 query détectée mais pas documentée dans spec

**Localisation :**
- `app/controllers/administrateurs/types_de_champ_controller.rb:123`

**Impact :**
- Performance dégradée si N > 20
- Pas de monitoring alertes

**Solution :**
1. Documenter trade-off dans spec (si N petit et acceptable)
2. OU optimiser avec `includes` / query unique

**Estimation fix :** 30 min (doc) ou 60 min (optimisation)

---

### Catégorie : Nice-to-Have (après merge)

#### 🟡 Nice-to-Have 1 : Helper pour DRY

**Problème :**
Code répété 3 fois pour formater tunnel_id

**Localisation :**
- `app/views/.../simplify.html.erb:12`
- `app/views/.../show.html.erb:34`
- `app/components/llm/header_component.rb:23`

**Solution :**
Créer helper `format_tunnel_id(tunnel_id)`

**Bénéfices :** DRY, maintenabilité

**Estimation fix :** 15 min

---

#### 🟡 Nice-to-Have 2 : Tests Edge Cases

**Problème :**
Edge cases non testés :
- Tunnel avec > 100 suggestions
- Schema change pendant workflow
- Concurrent access même tunnel

**Solution :**
Ajouter tests spécifiques pour ces scénarios

**Bénéfices :** Confiance accrue

**Estimation fix :** 45 min

---

## 🔴 Points Critiques (L'Horrible)

**Critères "horrible" :**
- Faille sécurité
- Fuite mémoire
- Deadlock possible
- Corruption données
- Breaking change non documenté

**Résultat pour cette feature :**
- [ ] Aucun point horrible détecté ✅
- [ ] [Nombre] points horribles à corriger IMMÉDIATEMENT

---

## 📝 Checklist de Fixes Priorisée

### 🔴 Bloquants (DOIT être fait avant merge)

- [ ] **Bloquant 1 :** Dead code `TunnelFinder` référencé
  - Fichiers : `app/components/llm/ai_component.rb`
  - Estimation : 10 min
  - Assigné : Agent

- [ ] **Bloquant 2 :** Tests système cassés (auto-enchainement)
  - Fichiers : `spec/system/administrateurs/simpliscore_spec.rb`
  - Estimation : 20 min
  - Assigné : Agent

- [ ] **Bloquant 3 :** Rubocop violations (15 offenses)
  - Fichiers : Multiples
  - Estimation : 15 min
  - Assigné : Agent

**Total bloquants :** 3 items, ~45 min

---

### 🟠 Importants (fortement recommandé avant merge)

- [ ] **Important 1 :** Logique métier → Query Object
  - Estimation : 20 min
  - Assigné : Agent

- [ ] **Important 2 :** N+1 query documentée
  - Estimation : 30 min
  - Assigné : Agent

- [ ] **Important 3 :** Memoization inappropriée
  - Estimation : 15 min
  - Assigné : Agent

**Total importants :** 3 items, ~65 min

---

### 🟡 Nice-to-Have (peut être fait après merge)

- [ ] **Nice 1 :** Helper DRY tunnel_id
  - Estimation : 15 min
  - Assigné : Backlog

- [ ] **Nice 2 :** Tests edge cases
  - Estimation : 45 min
  - Assigné : Backlog

- [ ] **Nice 3 :** Documentation inline
  - Estimation : 20 min
  - Assigné : Backlog

**Total nice-to-have :** 3 items, ~80 min

---

## 🎯 Pattern : Adaptation Tests Système

**Si feature change comportement (ex: auto-enchainement) :**

### AVANT (test assume ancien comportement)
```ruby
scenario 'workflow manuel' do
  click_button "Lancer recherche"
  # Attend état "recherche en cours"
  suggestion = create(:llm_rule_suggestion, ...)  # Créé manuellement
  visit simplify_path(...)
end
```

### APRÈS (test adapté au nouveau comportement)
```ruby
scenario 'workflow avec auto-enchainement' do
  click_button "Accepter"

  # La suggestion suivante est créée automatiquement
  # Utiliser find_by! au lieu de create
  suggestion_suivante = LLMRuleSuggestion.find_by!(
    tunnel_id: @tunnel_id,
    rule: 'improve_description'
  )

  expect(suggestion_suivante).to be_present
  expect(current_path).to include('improve_description')
end
```

**Pré-approuvé :**
- Adapter tests au nouveau comportement (pas juste skip)
- Utiliser `find_by!` pour entités auto-créées
- Tester redirection finale

---

## 🎯 Pattern : Déplacement Logique Métier

**Component → Query Object (pré-approuvé)**

### Avant

```ruby
# ❌ Component avec logique métier
class AiComponent
  def any_tunnel_finished?
    procedure.llm_rule_suggestions
      .exists?(rule: LAST, state: [:accepted, :skipped])
  end
end
```

### Après

```ruby
# ✅ Query Object
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

**Tests à ajouter :**
```ruby
# spec/queries/llm/tunnel_finished_query_spec.rb
RSpec.describe LLM::TunnelFinishedQuery do
  describe '.any_finished?' do
    # Tests isolation logique métier
  end
end
```

---

## 🔄 Workflow Review

### Étape 1 : Review Initiale (30-60 min)

**Actions :**
1. Lire tous commits de la PR
2. Identifier patterns (bon/mauvais/horrible)
3. Créer ce document review
4. Catégoriser points par gravité

---

### Étape 2 : Fixes Itératifs (1-3h selon complexité)

**Ordre obligatoire :**
1. 🔴 **Bloquants** (tous, pas de compromis)
2. 🟠 **Importants** (tous si temps permet, sinon user décide)
3. 🟡 **Nice-to-have** (backlog ou après merge)

**Workflow :**
```
Pour chaque fix :
1. Agent propose solution
2. User valide approche
3. Agent implémente
4. Tests passent
5. Update checklist (marquer ✅)
6. Commit avec git absorb
```

---

### Étape 3 : Git Absorb + Autosquash (15 min)

**Après tous fixes :**

```bash
# Absorbe changes dans commits existants
git add -p  # Sélectionner changes par hunk
git absorb  # Absorbe automatiquement

# Si commits trop fragmentés, squash
git rebase -i HEAD~N --autosquash
# Fusionner fixups dans commits principaux
```

**Bénéfices :**
- Historique clean (fixes intégrés dans commits originaux)
- Review plus facile (pas de "fix typo" commits)

---

### Étape 4 : Validation Finale (10 min)

**Checklist avant merge :**
- [ ] Tous bloquants résolus (🔴 = 0)
- [ ] Tous importants résolus OU documentés (🟠 acceptable si user OK)
- [ ] Tests passent (0 failures)
- [ ] Rubocop clean (0 offenses)
- [ ] Coverage ≥ 80%
- [ ] PR description mise à jour (breaking changes, fixes)

---

## 📊 Métriques Review

### Temps

| Phase | Temps Estimé | Temps Réel |
|-------|--------------|------------|
| Review initiale | 30-60 min | [Mesurer] |
| Fixes bloquants | 45 min | [Mesurer] |
| Fixes importants | 65 min | [Mesurer] |
| Git absorb | 15 min | [Mesurer] |
| **Total** | **2h30** | **[Mesurer]** |

### Qualité

| Métrique | Avant Review | Après Review |
|----------|--------------|--------------|
| **Bloquants** | [N] | 0 ✅ |
| **Importants** | [N] | 0 ✅ |
| **Nice-to-have** | [N] | [N backlog] |
| **Tests failures** | [N] | 0 ✅ |
| **Rubocop offenses** | [N] | 0 ✅ |

---

## 🎯 Décision Finale

**Status :** [À compléter après review]

- [ ] ✅ **MERGEABLE** - Tous bloquants résolus, prêt pour production
- [ ] ⚠️ **MERGEABLE avec réserves** - [N] importants backlog, documentés
- [ ] ❌ **PAS MERGEABLE** - [N] bloquants restants

**Prochaines étapes :**
- [Action 1]
- [Action 2]

---

## 🔗 Références

**PR :** #XXXX
**Spec :** `specs/YYYY-MM-DD-[nom]-spec.md`
**Plan :** `specs/YYYY-MM-DD-[nom]-implementation-plan.md`
**Methodology :** `pocs/4-features/setup.md`

---

**Template version :** 2.0
**Basé sur learnings :** Session 5 (Review & Cleanup)
**Status :** Stabilisé (testé sur 1 feature, N=1) — feature tunnel_id

