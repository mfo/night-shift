# Vue d'Ensemble des POCs

**Objectif :** Tester 4 types de tâches "agent-friendly" par ordre de complexité croissante

**Stratégie :** Commencer par les tâches LOW risk pour valider le workflow, puis monter en complexité

---

## 📊 Les 4 POCs Planifiés

| POC | Type de Tâche | Complexité | Risque | Temps Estimé | Priorité |
|-----|---------------|------------|--------|--------------|----------|
| **1** | Migration HAML→ERB | LOW | LOW | 30-45min | ✅ READY |
| **2** | Tests Lents - Optimisation | MEDIUM | LOW | 45-60min | ✅ READY |
| **3** | Bug Sentry Investigation | MEDIUM | MEDIUM | 2-3h | ✅ READY |
| **4** | Feature Simple (GitHub Issue) | MEDIUM-HIGH | MEDIUM | 2-4h | ✅ READY |

**Reportés Phase 2 :**
- Rubocop Auto-Fix (trop simple, pas assez de learning)
- Refacto Complexité (HIGH complexity, nécessite validation des autres POCs d'abord)

---

## 1️⃣ POC 1 : Migration HAML → ERB ✅

**Status :** READY TO LAUNCH

**Fichier cible :** `app/views/release_notes/_announce.html.haml` (10 lignes)

**Complexité :** LOW (conversion syntaxique, pas de logique métier)

**Risque :** LOW (tests system détectent régressions)

**Hypothèse à valider :**
- Claude peut convertir HAML→ERB en 30-45min autonome
- Markup HTML reste identique
- Tests passent sans modification
- Supervision minimale (0-1 intervention)

**Setup :** `pocs/1-haml/setup.md` ✅

**Worktree :** `/Users/mfo/dev/demarche.numerique.gouv.fr-poc-haml`

---

## 2️⃣ POC 2 : Tests Lents - Optimisation 🚀

**Status :** READY

**Objectif :** Optimiser 1-2 tests lents (> 5s) identifiés par profiling

**Complexité :** MEDIUM (nécessite analyse + compréhension test)

**Risque :** LOW (si comportement change, tests échouent)

**Hypothèse à valider :**
- Claude peut profiler les tests lents (`rspec --profile`)
- Identifier causes (factories lourdes, N+1, API calls)
- Optimiser sans changer comportement
- Mesurer gain réel (> 50% réduction temps)

**Tâche concrète suggérée :**
```bash
# Identifier les 10 tests les plus lents
cd /Users/mfo/dev/demarche.numerique.gouv.fr
bundle exec rspec --profile 10

# Choisir 1-2 tests > 5s
# Exemples potentiels :
# - spec/system/instructeur/dossier_spec.rb (souvent lent)
# - spec/system/usager/dossier_spec.rb
```

**Techniques attendues :**
- `create` → `build` (factories)
- `includes` pour éviter N+1
- `stub` pour external API calls
- Réduire setup inutile

**Temps estimé :** 45-60min

**Setup :** `pocs/2-tests/setup.md` ✅

---

## 3️⃣ POC 3 : Bug Sentry Investigation 🐛

**Status :** READY

**Objectif :** Investiguer + fixer 1 bug simple du backlog Sentry

**Complexité :** MEDIUM (nécessite analyse stack trace + compréhension code)

**Risque :** MEDIUM (touche code existant)

**Hypothèse à valider :**
- Claude peut analyser stack trace Sentry
- Identifier root cause
- Proposer fix avec tests
- Workflow investigation efficace

**Critères pour choisir un bug "agent-friendly" :**
- ✅ Stack trace claire et complète
- ✅ Occurrences > 10 (pattern répétitif)
- ✅ Catégories simples : N+1, nil check, validation, typo
- ❌ Pas de bug sécurité/auth
- ❌ Pas de logique métier ultra complexe

**Tâche concrète suggérée :**
```
Exemples de bugs "agent-friendly" :
- NoMethodError simple (nil check manquant)
- N+1 query détecté (includes manquant)
- Validation qui fail (edge case)
```

**Workflow attendu :**
1. Analyser stack trace (15-30min)
2. Reproduire avec test qui fail (30min)
3. Fix + vérifier test passe (30min-1h)
4. Vérifier non-régression (30min)
5. Rapport investigation (15min)

**Temps estimé :** 2-3h

**Setup :** `pocs/3-bugs/setup.md` ✅

**Note :** Nécessite accès à Sentry ou copie d'un bug existant

---

## 4️⃣ POC 4 : Feature Simple (GitHub Issue) 📝

**Status :** READY

**Objectif :** Implémenter 1 feature simple end-to-end

**Complexité :** MEDIUM-HIGH (full stack : model + controller + view + tests)

**Risque :** MEDIUM (nouvelle fonctionnalité)

**Hypothèse à valider :**
- Claude peut lire spec fonctionnelle GitHub issue
- Implémenter TDD (tests d'abord)
- Respecter contraintes (RGAA, sécurité, patterns)
- Livrer feature mergeable

**Critères pour feature "agent-friendly" :**
- ✅ Spec claire et détaillée
- ✅ Impact limité (< 3 fichiers)
- ✅ Acceptance criteria explicites
- ✅ Pas de migration DB complexe
- ❌ Pas de décision d'architecture
- ❌ Pas d'API publique

**Exemples de features "agent-friendly" :**
1. **Ajouter filtre dans liste**
   - Scope SQL simple
   - Formulaire avec 1-2 champs
   - Tests system + model

2. **Export CSV d'une ressource**
   - Controller action simple
   - CSV builder
   - Tests controller

3. **Amélioration UX mineure**
   - Ajouter tooltip
   - Modifier label
   - Ajouter icône

**Tâche concrète suggérée :**
```markdown
# Feature : Ajouter tri par date de modification sur liste dossiers

## Spec
- L'instructeur peut trier les dossiers par "Date de modification"
- Nouveau bouton dans header de colonne
- Tri ascendant/descendant

## Acceptance Criteria
- [ ] Bouton "Date modification" visible
- [ ] Click → tri ascendant
- [ ] Re-click → tri descendant
- [ ] URL reflète le tri (query param)
- [ ] Tests system passent

## Contraintes
- RGAA 4 (aria-label sur bouton)
- Performance (index DB si nécessaire)
```

**Workflow attendu :**
1. Lire spec + analyser impact (30min)
2. Écrire tests system (30min)
3. Implémenter scope + controller (1h)
4. Implémenter view (30min)
5. Vérifier contraintes (RGAA, perf) (30min)
6. Rapport (15min)

**Temps estimé :** 2-4h

**Setup :** `pocs/4-features/setup.md` ✅

---

## 📅 Planning Suggéré - Semaine 1

### Approche Progressive

**Lundi - POC 1 : HAML Migration** (45min + 30min review)
- ✅ Déjà prêt
- Risque minimal
- Valide le workflow de base

**Mardi - POC 2 : Tests Lents** (60min + 30min review)
- Complexité moyenne
- Mesure gain concret
- Valide capacité d'analyse

**Mercredi - Pause Kaizen** (2h)
- Remplir kaizen POC 1, 2
- Ajuster essentials.md selon learnings
- Préparer POC 3 si les 2 premiers OK

**Jeudi - POC 3 : Bug Sentry** (3h + 45min review)
- Si POC 1-2 validés (≥ 4/5)
- Sinon : itérer sur POC qui a coincé

**Vendredi - POC 4 : Feature Simple** (4h + 1h review)
- Si POC 1-3 validés
- Le plus complexe - validation complète du workflow

### Critère GO/NO-GO pour POC suivant

**Si POC 1-2 ont score moyen ≥ 4/5 :**
→ Continuer avec POC 3-4

**Si POC 1-2 ont score moyen < 4/5 :**
→ Itérer sur les prompts, ajuster workflow, retry

---

## 🎯 Métriques de Succès par POC

### POC Réussi (Score ≥ 4/5)
- ✅ Objectif atteint (code mergeable)
- ✅ Tests passent
- ✅ Temps < budget (+20% max)
- ✅ Supervision minimale (0-1 intervention)
- ✅ Rapport clair et actionnable

### POC Partiellement Réussi (Score 3/5)
- ⚠️ Objectif atteint avec ajustements manuels
- ⚠️ Tests passent mais temps dépassé
- ⚠️ 2-3 interventions nécessaires

### POC Échoué (Score ≤ 2/5)
- ❌ Code non mergeable
- ❌ Tests échouent
- ❌ Temps dépassé > 50%
- ❌ Supervision constante nécessaire

---

## 🔄 Après les 4 POCs

### Décision Phase 2

**Si 3-4 POCs validés :**
- Créer prompts complets (350-400 lignes chacun)
- Tester en batch (5-10 tâches par type)
- Mesurer ROI global

**Si 2 POCs validés :**
- Focus sur les types qui marchent
- Itérer sur les types qui coincent
- Peut-être abandonner les types trop complexes

**Si ≤ 1 POC validé :**
- Revoir hypothèse supervision minimale
- Augmenter contexte/documentation
- Ou pivoter vers workflow assisté (vs autonome)

---

## 📝 Prochaines Actions

### Maintenant - Tous les setups sont prêts ✅

**4 POCs préparés :**
- ✅ POC 1 : HAML Migration (`poc-1-haml-migration-setup.md`)
- ✅ POC 2 : Tests Lents (`poc-2-optimize-slow-tests-setup.md`)
- ✅ POC 3 : Bug Sentry (`poc-3-bug-sentry-setup.md` → renommer de `poc-4-...`)
- ✅ POC 4 : Feature Simple (`poc-4-simple-feature-setup.md` → renommer de `poc-5-...`)

**Action immédiate :**
- Lancer POC 1 selon `poc-1-haml-migration-setup.md`
- Documenter résultats dans `poc-1-haml-migration-results.md`
- Remplir `task-kaizen.md`
- Décider si continuer avec POC 2 selon learnings

---

**Principe :** On construit la confiance progressivement. LOW risk → MEDIUM risk → HIGH risk.
