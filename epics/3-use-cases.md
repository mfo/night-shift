# Epic 3 : Types de Demande 🎯

**Status :** 📋 To Do
**Effort :** 6-8h
**Priorité :** HIGH (contenu des prompts)

---

## 🎯 Objectif

**Problème :** Tous les use cases ne sont pas "agent-friendly". Certains nécessitent décisions humaines.

**Solution :** Identifier 5 types agent-friendly + créer prompts custom pour chacun

**Résultat attendu :**
- 5 prompts templates détaillés (1 par type de tâche)
- Critères de qualification (agent-friendly vs humain)
- Agents produisent code de qualité respectant patterns

---

## 📋 Les 5 Types de Tâches

### Vue d'Ensemble

| Type | Impact/Sem | Priorité | Complexité Agent | Risque |
|------|-----------|----------|------------------|--------|
| 1. Bug Sentry | 10-15h | HIGH | MEDIUM | MEDIUM |
| 2. Migration HAML | 5-8h | MEDIUM | LOW | LOW |
| 3. Refacto Complexité | 5h | MEDIUM | HIGH | MEDIUM |
| 4. Tests Lents | 3-5h | LOW | MEDIUM | LOW |
| 5. Issues GitHub | 5-15h | MEDIUM-HIGH | MEDIUM-HIGH | MEDIUM |

**Total gain potentiel :** 28-48h/semaine

---

## 1️⃣ Type 1 : Bug Sentry Investigation 🐛

### Caractéristiques

**Impact :** 10-15h/semaine (backlog actuel ~50 bugs)
**Priorité :** HIGH
**Complexité agent :** MEDIUM

### Critères "Agent-Friendly"

**✅ Délégable à l'agent :**
- Stack trace claire et lisible
- Occurrences > 10 (bug répétitif, pattern identifiable)
- Catégories simples : N+1, validations, typos logiques, nil checks
- Contexte reproductible

**❌ Nécessite humain :**
- Bugs sécurité / data corruption
- Bugs de logique métier complexe
- Bugs sans stack trace claire
- Bugs critiques (prod down)

### Workflow

```
1. Je copie/colle bug Sentry dans queue/bug-sentry-123.md
   → Stack trace
   → Contexte (fréquence, impact)

2. Agent investigue
   → Root cause analysis
   → Propose fix
   → Écrit tests

3. Je review rapport d'investigation
   → Décision merge/reject
   → 15min max
```

### Skill : `.claude/skills/bugfix/SKILL.md`

**Localisation :**
- Setup POC : `night-shift/pocs/3-bugs/setup.md`

**Structure du prompt (~400 lignes) :**

**Phase 1 : Analyse (30min)**
- Lire stack trace
- Identifier fichier + ligne exacte
- Comprendre contexte métier

**Phase 2 : Investigation (1h)**
- Reproduire localement (test qui fail)
- Analyser impact (nb users, depuis quand)
- Identifier 2-3 solutions possibles

**Phase 3 : Fix (1-2h)**
- Implémenter le fix
- Écrire tests (reproduire bug + vérifier fix)
- Vérifier non-régression (suite complète)

**Phase 4 : Rapport (15min)**
- Format investigation (root cause + solution + tests + impact)

**Contraintes :**
- Si bug touche auth/permissions → DEMANDER approbation
- Tests OBLIGATOIRES
- Coverage ≥ 80%

**Time Budget :** 3-4h max

**Template complet :** Voir SPEC-archive.md section 3.1

---

## 2️⃣ Type 2 : Migration HAML → ERB 🔄

### Caractéristiques

**Impact :** 5-8h/semaine (9.7% du codebase = ~300 fichiers HAML)
**Priorité :** MEDIUM
**Complexité agent :** LOW-MEDIUM

### Critères "Agent-Friendly"

**✅ Délégable :**
- Fichiers < 200 lignes
- Pas de logique Ruby complexe dans la vue
- Tests system specs existants (détecte régressions)

**❌ Nécessite humain :**
- Vues avec JS complexe
- Composants custom
- Logique métier dans vue

### Workflow

```
1. Je liste 3-5 fichiers HAML à migrer
   → queue/migrate-haml-12.md

2. Agent convertit
   → HAML → ERB (markup identique)
   → Lance tests system
   → Vérifie accessibilité

3. Je review diffs
   → Vérifier markup identique
   → Merge si tests green
```

### Prompt Template : `.claude/prompts/haml-migration.md`

**Localisation :**
- Template versionné : `worktree/.claude/prompts/haml-migration.md`
- Setup POC : `night-shift/pocs/1-haml/setup.md`

**Structure (~350 lignes) :**

**Phase 1 : Préparation (15min)**
- Lire fichiers HAML
- Identifier tests existants
- Vérifier tests passent AVANT

**Phase 2 : Migration (30min-1h par fichier)**
- Convertir HAML → ERB
- Conserver markup HTML identique
- Conserver ARIA labels (accessibilité)

**Règles de conversion :**
```haml
# HAML
%div.card
  %h2= @dossier.title
```

```erb
<!-- ERB -->
<div class="card">
  <h2><%= @dossier.title %></h2>
</div>
```

**Phase 3 : Validation (30min)**
- Vérifier accessibilité (RGAA 4)
- Lancer tests system
- Tous doivent passer

**Phase 4 : Rapport (10min)**
- Format simple (fichiers migrés + tests status)

**Contraintes :**
- RGAA 4 non-négociable
- Markup identique (à whitespace près)
- Tests system doivent passer

**Template complet :** Voir SPEC-archive.md section 3.2

---

## 3️⃣ Type 3 : Refactoring Code Complexe ♻️

### Caractéristiques

**Impact :** 5h/semaine (maintenance, dette technique)
**Priorité :** MEDIUM
**Complexité agent :** HIGH

### Critères "Agent-Friendly"

**✅ Délégable :**
- Méthode > 10 lignes (extraction service object)
- Duplication évidente (> 2 fois)
- Complexity score > 10 (Rubocop)

**❌ Nécessite humain :**
- Refacto d'architecture globale
- Décisions de design patterns majeurs

### Workflow

```
1. Je pointe méthode/classe complexe
   → queue/refacto-dossier-service-42.md
   → Localisation (fichier:ligne)
   → Métrique actuelle (lignes, complexity)

2. Agent propose 2 options de refacto
   → Option A (pros/cons)
   → Option B (pros/cons)
   → Je choisis ou demande ajustement

3. Agent implémente
   → Refacto choisi
   → Tests passent (comportement identique)

4. Je review
   → Code plus simple ?
   → Tests passent ?
   → Merge si OK
```

### Prompt Template : `.claude/prompts/refactor-complexity.md`

**Note :** POC Refacto reporté Phase 2 (HIGH complexity)

**Structure (~400 lignes) :**

**Phase 1 : Analyse (30min)**
- Comprendre code existant
- Identifier responsabilités multiples
- Repérer duplication

**Phase 2 : Proposition (30min)**
- Proposer 2 approches :
  - Approche A : Service Object
  - Approche B : Extract Methods
- Évaluer pros/cons

**Phase 3 : Implémentation (1-2h)**
- Implémenter approche choisie
- Adapter tests
- Vérifier non-régression

**Phase 4 : Rapport (15min)**
- Format investigation (avant/après + justification)

**Contraintes :**
- Comportement identique (tests passent sans modif)
- Respecter patterns du projet
- Simplicité (pas de sur-engineering)

**Template complet :** Voir SPEC-archive.md section 3.3

---

## 4️⃣ Type 4 : Tests Lents - Optimisation 🚀

### Caractéristiques

**Impact :** 3-5h/semaine (suite de tests prend ~10min)
**Priorité :** LOW (mais chronophage)
**Complexité agent :** MEDIUM

### Critères "Agent-Friendly"

**✅ Délégable :**
- Tests > 5s (détectés par `rspec --profile`)
- Causes communes : factories lourdes, N+1, sleep inutiles

**❌ Nécessite humain :**
- Tests lents pour raisons business (complexité inhérente)

### Workflow

```
1. Script génère liste top 10 tests lents
   → bin/find-slow-tests
   → queue/optimize-tests-5.md

2. Agent optimise
   → create → build
   → Stub external calls
   → Fix N+1
   → Mesure gain réel

3. Je review
   → Gain significatif ? (> 50%)
   → Tests passent ?
   → Merge
```

### Prompt Template : `.claude/prompts/optimize-tests.md`

**Localisation :**
- Setup POC : `night-shift/pocs/2-tests/setup.md`

**Structure (~350 lignes) :**

**Phase 1 : Analyse (30min)**
- Profiling : `bundle exec rspec --profile 10`
- Identifier causes (factories, N+1, API calls, sleep)

**Phase 2 : Investigation (1h)**
- Comprendre pourquoi c'est lent
- Mesurer impact potentiel

**Phase 3 : Optimisation (1-2h)**
- Techniques :
  ```ruby
  # create → build
  let(:dossier) { build(:dossier) }  # vs create

  # Stub external calls
  allow(ExternalService).to receive(:fetch).and_return(mock_data)

  # Fix N+1
  Dossier.includes(:user).each { |d| d.user.name }
  ```

**Phase 4 : Rapport (15min)**
- Format simple (gains avant/après)

**Contraintes :**
- Comportement identique
- Pas de faux positifs
- Objectif : réduire > 50%

**Template complet :** Voir SPEC-archive.md section 3.4

---

## 5️⃣ Type 5 : Issues GitHub → Implementation 📝

### Caractéristiques

**Impact :** 5-15h/semaine (selon complexité)
**Priorité :** MEDIUM-HIGH
**Complexité agent :** MEDIUM-HIGH

### Critères "Agent-Friendly" (Feature Simple)

**✅ Délégable :**
- Spec fonctionnelle claire et détaillée
- Pas de décision d'archi majeure
- Impact limité (< 3 fichiers)
- Acceptance criteria explicites

**Exemples :**
- Ajouter champ à formulaire
- Nouveau filtre dans liste
- Export CSV ressource
- Amélioration UX mineure

**❌ Nécessite humain :**
- Features stratégiques
- Décisions de design patterns
- Nouvelles API publiques

### Workflow

```
1. Je copie issue GitHub
   → queue/feature-export-csv-8.md
   → Spec fonctionnelle
   → Acceptance criteria

2. Agent implémente (TDD)
   → Tests d'abord
   → Implémentation
   → Vérifier contraintes (a11y, perf, sécu)

3. Je review
   → Feature fonctionne ?
   → Tests passent ?
   → Accessibilité OK ?
   → Merge
```

### Prompt Template : `.claude/prompts/simple-feature.md`

**Localisation :**
- Setup POC : `night-shift/pocs/4-features/setup.md`

**Structure (~400 lignes) :**

**Phase 1 : Compréhension (30min)**
- Lire spec fonctionnelle
- Analyser impact (quels fichiers ?)
- Planifier implémentation

**Phase 2 : Implémentation (2-3h)**
- TDD : écrire tests d'abord
  - System specs (UI)
  - Model/Service specs
- Implémenter (ordre : Model → Controller → View)
- Vérifier contraintes :
  - Accessibilité (RGAA 4)
  - Performance (N+1)
  - Sécurité (strong params)

**Phase 3 : Review & Polish (30min)**
- Rubocop
- Coverage ≥ 80%
- Documentation si nécessaire

**Phase 4 : Rapport (15min)**
- Format simple (feature + fichiers + tests)

**Contraintes :**
- Feature "simple" seulement (< 3 fichiers, pas de migration DB)
- RGAA 4 obligatoire
- Tests obligatoires
- Strong params obligatoires

**Si > 4h ou > 3 fichiers :**
→ Arrêter, escalader vers humain

**Template complet :** Voir SPEC-archive.md section 3.5

---

## 🗺️ Plan d'Implémentation

### Étape 1 : Décision Premier Use Case (30min)

**Question :** Sur quel use case commencer MVP ?

**Options :**

**A. Bug Sentry** (recommandé si API accessible)
- Impact : HIGH
- ROI rapide : OUI
- Risque : MEDIUM

**B. Migration HAML** ⭐ **RECOMMANDÉ pour MVP**
- Impact : MEDIUM
- ROI rapide : OUI
- Risque : LOW (tests détectent régressions)
- Prérequis : Aucun

**C. Tests Coverage** (alternatif)
- Impact : MEDIUM
- ROI rapide : MOYEN
- Risque : TRÈS LOW

**Critères de choix :**
- Risque le plus faible
- Pas de dépendance externe
- Résultats faciles à valider

### Étape 2 : Écrire Premier Prompt (2-3h)

**Choisir 1 use case → écrire prompt complet**

**Structure d'un prompt :**
1. Contexte (qui tu es, objectif)
2. Instructions par phase (4 phases typiques)
3. Contraintes (sécurité, perf, a11y, tests)
4. Format de rapport attendu
5. Time budget
6. Checklist finale
7. Exemple de session (input → output)

**S'inspirer de :** SPEC-archive.md section 3 (5 prompts détaillés)

### Étape 3 : Tester Premier Prompt (2-3h)

**Créer 1 tâche réelle dans queue/**

```bash
# Exemple : Migration HAML
cat > .claude/tasks/queue/migrate-haml-test-1.md <<EOF
# Migration HAML → ERB (Test 1)

## Contexte
Test du workflow fire-and-forget

## Fichiers à migrer
- app/views/dossiers/_header.html.haml

## Contraintes
- Tests system doivent passer
- RGAA 4 strict

## Livrable
- Fichier ERB
- Tests green
- Rapport dans done/
EOF
```

**Lancer avec script :**
```bash
bin/launch-night-task migrate-haml-test-1
```

**Évaluer :**
- Prompt clair ? Agent a compris ?
- Rapport lisible ?
- Code respecte patterns ?
- Tests passent ?
- Gain de temps mesuré ?

### Étape 4 : Ajuster Prompt (1h)

**Selon résultats du test :**
- Sections manquantes ?
- Contraintes pas respectées ?
- Rapport incomplet ?

→ Améliorer le prompt template

### Étape 5 : Valider (retry 2-3 fois)

**Objectif :** Taux de merge > 80% sur 3 tâches

**Si succès :**
→ Passer au 2ème use case

**Si échec :**
→ Itérer sur prompt ou pivoter use case

### Étape 6 : Scale (Phase 2)

**Ajouter les 4 autres prompts**

**Ordre recommandé :**
1. Migration HAML (LOW risk) ✅
2. Tests lents (LOW risk)
3. Bug Sentry (MEDIUM risk)
4. Features simples (MEDIUM risk)
5. Refacto complexité (HIGH complexity)

---

## ✅ Critères d'Acceptance

### Epic 3 Complet (Phase 1)

- [ ] 1 prompt template complet (use case MVP)
- [ ] Prompt testé 3 fois (taux merge > 80%)
- [ ] Prompt ajusté selon feedback
- [ ] Documentation use case (critères agent-friendly)

### Epic 3 Complet (Phase 2)

- [ ] 5 prompts templates écrits
- [ ] Chaque prompt testé 2-3 fois
- [ ] Taux merge global > 60%
- [ ] Documentation des 5 use cases

### Qualité Prompts

- [ ] Instructions claires et directves (étape par étape)
- [ ] Contraintes explicites (sécurité, a11y, perf)
- [ ] Format de rapport défini
- [ ] Time budget réaliste
- [ ] Checklist finale
- [ ] Exemple concret (input → output)

---

## 📊 Métriques de Succès

### Par Use Case

**Tracker :**
- Taux de merge : > 80% (use case facile), > 60% (use case complexe)
- Temps agent vs temps humain : gain > 50%
- Respect patterns : > 90%
- Tests passent : 100%
- Violations contraintes critiques : 0%

### Global (5 use cases)

**Objectif Phase 2 :**
- Taux merge moyen : > 60%
- Gain temps total : > 10h/semaine
- Workflow fire-and-forget validé : 100% (pas de supervision)

---

## 🔗 Ressources

**Templates complets :**
Voir `SPEC-archive.md` section 3 pour les 5 prompts détaillés (~400 lignes chacun)

**Références :**
- Epic 1 : Fichiers de contexte (utilisés par prompts)
- Epic 2 : Templates de rapports (format attendu)
- Roadmap : `roadmap.perso.md`

---

## 🎯 Prochaines Étapes

**Session Prochaine :**

1. **Décision 1 : Premier Use Case MVP** (10min)
   → Migration HAML OU Tests OU Bug Sentry ?

2. **Écrire Prompt Template** (2-3h)
   → S'inspirer de SPEC-archive.md section 3
   → Adapter à use case choisi

3. **Tester sur Tâche Réelle** (2-3h)
   → Créer tâche dans queue/
   → Lancer avec script
   → Évaluer résultats

4. **Itérer** (1h)
   → Améliorer prompt selon feedback
   → Retry jusqu'à taux merge > 80%

**Après Epic 3 Phase 1 :**
→ Décision Go/No-Go Phase 2 (scale aux 5 use cases)

---

*Epic 3 v1.0 - 2026-03-08*
