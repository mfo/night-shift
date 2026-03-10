# CONTEXT - Roadmap & État du Projet

**Dernière MAJ :** 2026-03-10
**Objectif :** Roadmap pour reprendre les travaux et décider de la suite

---

## 🎯 Vision (rappel)

Déléguer des tâches répétitives à des agents IA. Apprendre ce qui marche (et ce qui échoue). Améliorer les prompts progressivement.

**Projet pilote :** demarche.numerique.gouv.fr (Rails, HAML→ERB, bugs, tests)

---

## ✅ Ce qui est fait

### Ground 0 (commit initial)
- [x] Structure du projet (README, WORKFLOW, epics, POCs)
- [x] README simplifié (sans jargon, accessible)
- [x] Prompt HAML→ERB basique
- [x] essentials.md vide (évolutif)
- [x] Templates kaizen

### Building blocks
- [x] Hook worktree isolation DB (`hooks/worktree/`)
  - Auto-création DB unique par worktree
  - Documentation complète
  - Script d'installation

### POC 1 : HAML→ERB Migration

#### Phase 1.1 - Premier test (12 fichiers)
- [x] Migration 12 composants DSFR
- [x] 4 erreurs critiques découvertes
- [x] Kaizen documenté
- [x] Prompt amélioré v2

**Résultats Phase 1.1 :**
- Temps : 48min (25min migration + 23min corrections CI)
- Score : 3/10
- Hypothèse "fire-and-forget" INVALIDÉE

**Learnings :**
1. Arrays de classes → `.join(' ')` obligatoire
2. Balises auto-fermantes → HTML5 interdit `<input />`
3. Espacement → ERB préserve, utiliser `<%-` et `-%>`
4. Guillemets → HAML `'`, ERB `"`
5. **Validation locale OBLIGATOIRE** (linter + tests avant commit)

#### Phase 2.8a - Test prompt amélioré (5 fichiers)
- [x] Migration 5 composants simples
- [x] 1 erreur découverte (Pattern 5: String interpolation helpers)
- [x] Kaizen documenté
- [x] Prompt v3 (batch 15 fichiers, autonomie renforcée)

**Résultats Phase 2.8a :**
- Temps : 35min (25min migration + 5min validation + 5min correction)
- Score : **8/10** ✅ (objectif atteint)
- Amélioration : -75% erreurs, -67% amends, -27% temps

**Learning Phase 2.8a :**
- Pattern 5 : String interpolation helpers (`"#{link_to...}"` échappe HTML)
- Autonomie : Permission `rm app/**/*.haml` pré-approuvée
- Sélection auto batch (max 15 fichiers, critères simplicité)

**Progression :** 17/758 fichiers HAML (2.2%)

---

## 🎯 Roadmap - Prochaines étapes

### Priorité 1 : Valider prompt amélioré

**Objectif :** Passer de 3/10 à 8/10

**Actions :**
- [ ] Tester prompt amélioré sur Phase 1.2 (5 fichiers)
- [ ] Mesurer : erreurs, amends, temps, score
- [ ] Objectif : 0 erreur CI, 0 amend, validation locale détecte tout
- [ ] Documenter dans nouveau kaizen

**Critère de succès :**
- Score ≥ 8/10
- 0 amend (git history propre)
- Validation locale a catché toutes les erreurs

**Si succès → passer à Priorité 2**
**Si échec → analyser, améliorer prompt v3, réitérer**

---

### Priorité 2 : Étendre HAML→ERB

**Objectif :** Valider sur d'autres types de composants

**Actions :**
- [ ] Phase 1.3 : Autres composants (5 fichiers)
- [ ] Phase 1.4+ : Continuer par batches de 5
- [ ] Mesurer stabilité du score (maintien à 8/10 ?)
- [ ] Identifier nouveaux patterns si nécessaire

**Critère de succès :**
- Score stable ≥ 8/10 sur 3 phases consécutives
- Prompt n'a pas besoin d'évolution majeure

**Si succès → passer à Priorité 3**
**Si instabilité → améliorer prompt jusqu'à stabilisation**

---

### POC 3 : Bugs Sentry (Investigation/Implémentation Split)

- [x] Bug traité : Sentry #7113029548 (Faraday::TooManyRequestsError Mistral API 429)
- [x] Prompts créés : `investigate-sentry-bug.md` + `fix-sentry-bug.md`
- [x] Kaizen investigation + implémentation documentés
- [x] 3 patterns découverts (Rate limiting API, Enqueue massif, Suppression > Désactivation)

**Résultats POC 3 :**
- Temps total : 65min (investigation 45min + implémentation 20min)
- Score global : **4.7/5** ✅
  - Score investigation : 4.4/5
  - Score implémentation : 4.8/5
- Gain de temps : **~50%** vs approche monolithique (2-3h)

**Approche validée : Investigation/Implémentation Split**
- Agent 1 : Investigation (analyse, 5 Whys, 3 solutions proposées)
- Agent 2 : Implémentation (fix, tests, validation)
- Handoff : Rapport investigation = interface claire (0 question, 0 re-investigation)

**Patterns découverts :**
1. **Rate Limiting API Externes :** Jobs Sidekiq + API externe sans throttling → 429
2. **Jobs Cron Enqueue Massif :** `find_each { perform_later }` → tempête de jobs
3. **Suppression > Désactivation :** Feature non-critique → supprimer (Git history préserve)

**Hypothèses validées :**
- Split investigation/implémentation = plus efficace pour bugs complexes (gain 50%)
- Rapport investigation suffit comme handoff (0 question nécessaire)
- Patterns réutilisables existent (rate limiting récurrent)

**Hypothèses invalidées :**
- Investigation sans questions business (3 questions nécessaires)
- "Toujours désactiver avec ENV" (contexte business prime)

**À valider (prochaines itérations) :**
- Split utile pour bugs simples ? (overhead handoff vs gain)
- Parallélisation investigation/implémentation = gain ?

---

### Priorité 3 : Continuer POCs

**POCs disponibles :**

1. **POC 2 : Tests lents**
   - [ ] Identifier tests > 1s
   - [ ] Créer prompt optimisation tests
   - [ ] Tester sur 3-5 tests
   - [ ] Documenter patterns (N+1, fixtures, etc.)

2. **POC 3 : Bugs Sentry** (suite)
   - [ ] Tester sur bug simple (NoMethodError) pour valider split vs monolithic
   - [ ] Mesurer overhead handoff
   - [ ] Tester parallélisation investigation/implémentation

3. **POC 4 : Features simples**
   - [ ] Choisir 1 feature simple (CRUD, etc.)
   - [ ] Créer prompt implémentation feature
   - [ ] Tester sur 1-2 features
   - [ ] Documenter patterns architecture

**Stratégie :**
- Même approche : prompt basique → test → kaizen → améliorer
- Objectif : score ≥ 7/10 (apprentissage transférable)

---

### Backlog : Améliorations futures

**Documentation :**
- [ ] Améliorer QUICKSTART.md avec exemples concrets
- [ ] Créer guide "Comment choisir un POC pour votre projet"
- [ ] Vidéo démo (optionnel)

**Outillage :**
- [ ] Script `bin/worktree-create` (création + installation hook)
- [ ] Script `bin/worktree-cleanup` (suppression worktree + DB)
- [ ] Dashboard métriques (scores par phase, temps, etc.)

**Méthode :**
- [ ] Extraire patterns réutilisables (au-delà de HAML→ERB)
- [ ] Guide "Appliquer Night Shift à votre projet"
- [ ] Template pour nouveaux POCs

---

## 📊 Métriques & Objectifs

### Métriques actuelles

| POC | Phase | Tâche | Score | Erreurs | Amends | Temps |
|-----|-------|-------|-------|---------|--------|-------|
| 1   | 1.1   | HAML→ERB (12 fichiers) | 3/10 | 4 | 3 | 48min |
| 1   | 2.8a  | HAML→ERB (5 fichiers) | **8/10** ✅ | 1 | 1 | 35min |
| 3   | -     | Bug Sentry (investigation + fix) | **4.7/5** ✅ | 0 | 0 | 65min |

### Objectifs prochaines phases

| POC | Phase | Tâche | Score visé | Erreurs | Amends | Temps |
|-----|-------|-------|------------|---------|--------|-------|
| 1   | 2.8b+ | HAML→ERB (15 fichiers) | 8/10 | 0 | 0 | ≤50min |
| 3   | suite | Bug simple (NoMethodError) | 4/5 | 0 | 0 | ≤30min |

### Définition des scores

- **10/10** : Perfection (0 erreur, 0 amend, < 30min)
- **8/10** : Oneshot pratique (validation locale détecte tout, 0 amend)
- **5/10** : Utilisable (1 amend max, < 1h)
- **3/10** : Non viable (plusieurs amends, > 1h)
- **1/10** : Échec total

---

## 🔧 Décisions techniques à prendre

### Court terme (Phase 1.2)

**Question :** Re-tester Phase 1.1 ou commencer Phase 1.2 ?
- Option A : Re-tester même batch (valide que prompt v2 corrige vraiment)
- Option B : Nouveau batch (avance sur la migration)
- **Recommandation :** Option B (on a déjà le kaizen de 1.1)

**Question :** Taille du batch ?
- Prompt dit "5 fichiers max"
- **Recommandation :** Commencer avec 3 fichiers (prudence), puis 5 si OK

### Moyen terme (après Phase 1.3)

**Question :** Quand passer au POC 2 ?
- Après stabilisation HAML→ERB (3 phases à 8/10)
- Ou dès maintenant pour diversifier l'apprentissage ?
- **À décider selon résultats Phase 1.2**

---

## 📁 Fichiers importants

### Pour reprendre les travaux
- `CONTEXT.md` : Ce fichier (roadmap)
- `WORKFLOW.md` : Guide pratique POC + kaizen→commit
- `README.md` : Vision du projet

### Pour les POCs

**POC 1 - HAML→ERB :**
- `pocs/1-haml/setup.md` : Setup
- `.claude/prompts/haml-migration.md` : Prompt v3 (batch 15, 5 patterns)
- `kaizen/poc-haml-migration/` : Learnings Phase 1.1 + 2.8a

**POC 3 - Bugs Sentry :**
- `pocs/3-bugs/setup.md` : Setup
- `.claude/prompts/investigate-sentry-bug.md` : Prompt investigation
- `.claude/prompts/fix-sentry-bug.md` : Prompt implémentation
- `kaizen/poc-3-bugs/` : Learnings investigation + implémentation

### Infrastructure
- `hooks/worktree/` : Isolation DB par worktree

---

## 🚀 Template pour reprendre

Copie ce template quand tu reviens sur le projet :

```markdown
# Contexte
Night Shift - Démonstrateur pipelines de dev avec IA
État : Voir CONTEXT.md section "Ce qui est fait"

# Objectif session
[Choisir dans la roadmap]
- Option 1 : Valider prompt amélioré (Phase 1.2)
- Option 2 : Continuer HAML→ERB (Phase 1.3+)
- Option 3 : Explorer POC 2/3/4
- Option 4 : Améliorer documentation

# Ce que je veux faire
[Décrire précisément]

# Question
Quelle est la meilleure façon de procéder ?
```

---

## 🎓 Rappels importants

**Petits pas :** Ne pas chercher la perfection du premier coup
**Documenter les échecs :** Les erreurs sont le matériau de l'apprentissage
**Histoire git fluide :** Chaque commit raconte l'évolution
**Validation locale obligatoire :** Ne JAMAIS commiter sans linter + tests

---

**Dernière session :** 2026-03-10
**Accomplissements :**
- POC 1 Phase 2.8a : Score 8/10 atteint ✅ (prompt v3 validé)
- POC 3 : Investigation/Implementation split validé, score 4.7/5 ✅

**Prochains objectifs :**
- POC 1 : Continuer migration HAML→ERB (batch 15, stabiliser 8/10)
- POC 3 : Tester split sur bug simple (valider approche monolithic vs split)

**Status :** 2 POCs validés, méthode qui fonctionne
