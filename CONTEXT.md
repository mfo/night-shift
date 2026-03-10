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

#### Phase 3.1 - Batch ultra-simples (15 fichiers)
- [x] Migration 15 composants ultra-simples (1-2 lignes)
- [x] Prompt v3.1 (`git rm` au lieu de `rm`)
- [x] Validation à 3 niveaux (linter + grep + tests)
- [x] Kaizen session complète documenté

**Résultats Phase 3.1 :**
- Temps : 20min migration (prévu 50min) + 20min total session
- Score migration : **8/10**, Score session : **9/10** ✅
- Amélioration : -60% temps vs prévu, 0 erreur
- PR validée ✅

**Learnings Phase 3.1 :**
- Stratégie "ultra-simples d'abord" (tri par taille) = zéro risque
- `git rm` fonctionne sans permission (vs `rm` refusé)
- Workflow collaboratif user↔agent très efficace (validation incrémentale)
- Kaizen post-migration systématique prédit succès (8-9/10 = green light)

**Progression :** 109/758 fichiers HAML migrés (14.4% → 649 restants)

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

### POC 4 : Specs Architecture (avec Review PM)

- [x] Spec traitée : Refactoring Simpliscore tunnel_id (bug architectural)
- [x] Setup créé : `pocs/4-spec/setup.md` (modèle 3 phases)
- [x] Prompt créé : `create-spec.md` (suit le setup.md)
- [x] Kaizen documenté : Phase spec uniquement (implémentation à venir)
- [x] 3 patterns découverts (Preuve mathématique, Query Object DRY, Trade-offs)

**Résultats POC 4 :**
- Temps total : 5h30 (analyse 30min + conception 1h + rédaction 1h30 + review PM 45min + itérations 1h30)
- Score : **7/10 seul, 9/10 avec review PM** ✅
- Review PM findings : 15 problèmes détectés (4 critiques, 11 importants)
- Itérations user : 8 rounds sans friction

**Workflow 3 phases validé :**
1. **Analyse & Rédaction spec v1** (2-3h) : Analyse problème, conception architecture, template 15 sections
2. **Review Agent PM** (45min-1h) : Obligatoire si > 500 lignes, focus 10 points critiques
3. **User Review + Décisions** (1-2h) : Validation architecture, itérations rapides (max 8)

**Patterns découverts :**
1. **Preuve Mathématique de Bug :** Au lieu de "ça marche pas", prouver condition impossible → conviction immédiate
2. **Query Object pour DRY :** Logique répétée 3+ fois → extraire dans Query Object (testable, extensible)
3. **Documentation Trade-offs :** Template Choix/Alternative/Rationale/Impact → évite débats futurs

**Hypothèses validées :**
- Review agent PM efficace pour specs > 500 lignes (15 problèmes détectés)
- Itérations rapides user + agent fonctionnent (8 rounds sans friction)
- Query Object proactif apprécié (user a approuvé immédiatement)
- Documentation trade-offs évite débats futurs

**Hypothèses invalidées :**
- Fire-and-forget pour specs architecture (décisions métier nécessaires)
- Estimation temps précise (réalité = 2x estimation initiale)

**Règle critique :**
Bug architectural détecté → STOP et spec globale, pas patch incrémental

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

3. **POC 4 : Specs Architecture** (suite)
   - [ ] Implémenter spec Simpliscore tunnel_id (8-20h estimé)
   - [ ] Mesurer temps implémentation vs. estimation
   - [ ] Valider que spec production-ready accélère implémentation

4. **POC 5 : Plans d'Implémentation Atomiques** (nouveau)
   - [x] Setup créé : `pocs/5-simpliscore-refactoring/setup.md` (modèle 3 phases)
   - [ ] Créer prompt : `create-implementation-plan.md` (suit le setup.md)
   - [ ] Tester sur spec Simpliscore tunnel_id (17 commits atomiques)
   - [ ] Mesurer : temps plan, exécutabilité par agent codeur, code review facilité

**Stratégie :**
- Même approche : setup.md (modèle) + prompt (guide agent) → test → kaizen → améliorer
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
| 1   | 3.1   | HAML→ERB (15 fichiers ultra-simples) | **8/10 migration, 9/10 session** ✅ | 0 | 1 | 20min |
| 3   | -     | Bug Sentry (investigation + fix) | **4.7/5** ✅ | 0 | 0 | 65min |
| 4   | spec  | Spec architecture (Simpliscore) | **7/10 seul, 9/10 PM** ✅ | - | - | 5h30 |

### Objectifs prochaines phases

| POC | Phase | Tâche | Score visé | Erreurs | Amends | Temps |
|-----|-------|-------|------------|---------|--------|-------|
| 1   | 3.2+ | HAML→ERB (15 fichiers moyens 3-10 lignes) | 8/10 | 0 | 0 | ≤30min |
| 3   | suite | Bug simple (NoMethodError) | 4/5 | 0 | 0 | ≤30min |
| 5   | plan | Plan implémentation Simpliscore | 8/10 | - | - | ≤2h |

### Définition des scores

- **10/10** : Perfection (0 erreur, 0 amend, < 30min)
- **8/10** : Oneshot pratique (validation locale détecte tout, 0 amend)
- **5/10** : Utilisable (1 amend max, < 1h)
- **3/10** : Non viable (plusieurs amends, > 1h)
- **1/10** : Échec total

---

## 🔧 Décisions techniques à prendre

### Court terme (Phase 3.2)

**Question :** Continuer HAML→ERB ou démarrer POC 5 ?
- Option A : Phase 3.2 (15 fichiers moyens 3-10 lignes) → consolider HAML
- Option B : POC 5 (plan implémentation Simpliscore) → valider nouveau workflow
- **Recommandation :** Option B (spec Simpliscore prête, POC 5 setup créé)

**Question :** Versionner `.claude/prompts/` ?
- Prompt v3.1 (avec `git rm`) n'est pas versionné (`.gitignore` bloque)
- Session dédiée infrastructure nécessaire ?
- **À décider :** Impact sur partage amélioration prompts

### Moyen terme (POC 5 validé)

**Question :** Reprendre migration HAML→ERB ou continuer POCs ?
- Option A : Phases 3.2-3.X jusqu'à 0 fichier HAML (649 restants)
- Option B : POC 2 (Tests lents) pour diversifier
- **À décider selon résultats POC 5**

---

## 📁 Fichiers importants

### Pour reprendre les travaux
- `CONTEXT.md` : Ce fichier (roadmap)
- `WORKFLOW.md` : Guide pratique POC + kaizen→commit
- `README.md` : Vision du projet

### Pour les POCs

**POC 1 - HAML→ERB :**
- `pocs/1-haml/setup.md` : Setup
- `.claude/prompts/haml-migration.md` : Prompt v3.1 (batch 15, `git rm`, 5 patterns)
- `kaizen/poc-haml-migration/` : Learnings Phase 1.1 + 2.8a + 3.1

**POC 3 - Bugs Sentry :**
- `pocs/3-bugs/setup.md` : Setup
- `.claude/prompts/investigate-sentry-bug.md` : Prompt investigation
- `.claude/prompts/fix-sentry-bug.md` : Prompt implémentation
- `kaizen/poc-3-bugs/` : Learnings investigation + implémentation

**POC 4 - Specs Architecture :**
- `pocs/4-spec/setup.md` : Setup (modèle 3 phases, 15 sections)
- `.claude/prompts/create-spec.md` : Prompt création spec
- `kaizen/simpliscore-tunnel-id-spec.md` : Learnings phase spec
- `pocs/4-features/simpliscore-tunnel-id-results.md` : Résultats phase spec

**POC 5 - Plans Implémentation Atomiques :**
- `pocs/5-simpliscore-refactoring/setup.md` : Setup (modèle 3 phases, commits atomiques)
- `.claude/prompts/create-implementation-plan.md` : À créer

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
- POC 1 Phase 3.1 : Score 9/10 session complète ✅ (109 fichiers migrés, prompt v3.1, stratégie "ultra-simples d'abord")
- POC 3 : Investigation/Implementation split validé, score 4.7/5 ✅
- POC 4 : Workflow specs architecture créé, score 7/10→9/10 avec review PM ✅
- POC 5 : Setup créé (plans implémentation atomiques) ✅

**Prochains objectifs :**
- POC 5 : Créer prompt + tester sur spec Simpliscore (17 commits atomiques)
- POC 1 : Continuer migration HAML→ERB Phase 3.2+ (649 fichiers restants)
- POC 3 : Tester split sur bug simple (valider approche monolithic vs split)
- POC 4 : Implémenter spec Simpliscore tunnel_id via POC 5

**Status :** 4 POCs (3 validés, 1 en setup), méthode qui fonctionne, 109 fichiers HAML migrés
