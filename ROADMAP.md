# ROADMAP - État du Projet & Prochaines Étapes

**Objectif :** Vue d'ensemble du projet et prochaines expérimentations

---

## 🎯 Vision (rappel)

Déléguer des tâches répétitives à des agents IA. Apprendre ce qui marche (et ce qui échoue). Améliorer les skills progressivement.

**Projet pilote :** demarches.simplification.gouv.fr (Rails, HAML→ERB, bugs, features)

---

## ✅ Ce qui est fait

### POC 1 : HAML→ERB Migration

**Progression :** 109/758 fichiers migrés (14.4%)

**Évolution skill :**
- **Phase 1.1** (12 fichiers) : Score 3/10 → 4 erreurs critiques
  - 📄 [Kaizen Phase 1.1](kaizen/1-haml/2026-03-09-phase-1.1-dsfr-components.md)
- **Phase 2.8a** (5 fichiers) : Score 8/10 → 1 erreur, skill v2
  - 📄 [Kaizen Phase 2.8a](kaizen/1-haml/2026-03-09-phase-2.8a-autres-components.md)
- **Phase 3.1** (15 fichiers) : Score 9/10 → 0 erreur, skill v3 stable
  - 📄 [Kaizen Phase 3.1](kaizen/1-haml/kaizen-2026-03-10-phase-3.1.md)
  - 📄 [Session complète](kaizen/1-haml/kaizen-2026-03-10-session-complete.md)

**Score moyen :** 7.7/10 (évolution 3→8→9)

**Learnings clés :**
- 5 patterns critiques identifiés (arrays, balises, espacement, guillemets, helpers)
- Validation locale obligatoire (linter + tests)
- Stratégie "ultra-simples d'abord" = zéro risque

**Status :** ✅ Skill v3 production-ready pour fichiers simples

---

### POC 3 : Bugs Sentry

**Traité :** 1 bug complexe (Mistral API 429 - Rate Limiting)

**Workflow validé :** Investigation/Implémentation split
- **Investigation** : 45min → Score 4.4/5
  - 📄 [Kaizen Investigation](kaizen/3-bugs/2026-03-10-bug-429-mistral-api-investigation.md)
- **Implémentation** : 20min → Score 4.8/5
  - 📄 [Kaizen Implémentation](kaizen/3-bugs/2026-03-10-bug-429-mistral-api-implementation.md)

**Score global : 4.7/5** ✅

**Learnings clés :**
- Split = 50% gain temps vs approche monolithique
- Handoff clair (rapport investigation) = 0 question nécessaire
- 3 patterns découverts (Rate limiting API, Enqueue massif, Suppression > Désactivation)

**Status :** ✅ Workflow production-ready pour bugs complexes

---

### POC 4 : Features Complexes

**Traité :** 1 feature architecture (Simpliscore tunnel_id - spec + plan)

**Workflow 4 phases :**
- **Phase 0 : Create-Spec** (5h30) → Score 7/10 seul, 9/10 avec review PM ✅
  - 📄 [Kaizen Spec Creation](kaizen/4-features/iteration-1/kaizen-spec-creation.md)
- **Phase 1 : Create-Plan** (1h30) → Score 8/10, 17 commits atomiques ✅
  - 📄 [Kaizen Plan Creation](kaizen/4-features/iteration-1/kaizen-plan-creation.md)
- **Phase 2 : Implementation** → À valider (8-15h estimé)
  - 📄 [Session 1](kaizen/4-features/iteration-1/session-1-simpliscore-implementation.md)
  - 📄 [Session 2](kaizen/4-features/iteration-1/session-2-simpliscore-implementation.md)
- **Phase 3 : Review & Cleanup** → À valider (1-3h estimé)
  - 📄 [Session 5 Review](kaizen/4-features/iteration-1/session-5-review-cleanup.md)

**Score moyen : 8.2/10** (phases 0-1 validées)

**Learnings clés :**
- Review agent PM détecte 15 problèmes critiques (spec > 500 lignes)
- 10 patterns agent-friendly documentés (Tests verts, Migration DB Safe, Query Object DRY, etc.)
- Plan atomique (< 20 commits, 7 phases) facilite implémentation
- 📄 [Kaizen learnings additionnels](kaizen/4-features/iteration-1/) : Schema change detection, Git history reconstruction, Self-documenting variables

**Status :** ⚠️ Phases 0-1 validées, Phases 2-3 à valider empiriquement

---

## 🎯 Prochaines Étapes

### POC 1 : HAML→ERB Migration

**Objectif :** Validation visuelle automatisée (MCP/screenshot)

**Contexte :** Skill v3 stable (9/10) mais validation manuelle nécessaire. MCP Playwright peut automatiser screenshots avant/après pour comparer visuellement.

**Actions :**
- [ ] Expérimenter MCP Playwright pour screenshots HAML vs ERB
- [ ] Créer workflow "migration + screenshot + comparaison visuelle"
- [ ] Tester sur batch 5-10 fichiers
- [ ] Documenter si validation visuelle détecte erreurs que linter rate

**Critère succès :** Validation visuelle automatique détecte différences subtiles (spacing, rendering)

**Référence :** `specs/2026-03-11-haml-visual-validation-input.md`

---

### POC 3 : Bugs Sentry

**Objectif :** Renforcer autonomie via kaizen continu

**Contexte :** Workflow split validé (4.7/5) sur bug complexe. Tester sur bugs simples + identifier patterns récurrents.

**Actions :**
- [ ] Traiter 3-5 bugs simples (NoMethodError, N+1, validations)
- [ ] Mesurer autonomie : questions posées, interventions nécessaires
- [ ] Identifier patterns récurrents → enrichir skills
- [ ] Comparer split vs monolithic sur bugs simples (overhead handoff ?)

**Critère succès :** Score stable ≥ 4/5 sur 3 bugs consécutifs, patterns réutilisables documentés

---

### POC 2 : Tests Lents (Optimisation)

**Objectif :** Reproduire approche `let_it_be` avec agent

**Contexte :** [PR #12738](https://github.com/demarche-numerique/demarche.numerique.gouv.fr/pull/12738) (tchak) démontre pattern efficace d'optimisation tests avec `let_it_be` (test-prof). Agent peut-il identifier specs lourdes et appliquer même transformation ?

**Pattern validé (PR tchak) :**
- Conversion `let`/`let!` → `let_it_be` dans specs lourdes
- Réutilisation objets factory entre exemples → moins de créations DB
- Isolation garantie avec `reload: true` quand nécessaire
- 16 fichiers optimisés sur 9 commits atomiques

**Actions :**
- [ ] Analyser PR #12738 pour extraire patterns de transformation
- [ ] Identifier autres specs lourdes candidates (profiling RSpec)
- [ ] Créer skill "optimiser specs avec let_it_be"
- [ ] Tester sur 3-5 fichiers specs
- [ ] Mesurer gain temps exécution réel

**Critère succès :** Agent identifie specs lourdes et applique transformation `let_it_be` correctement, tests restent verts, gain temps mesurable

---

### POC 4 : Features Complexes

**Objectif :** Valider workflow complet (implémentation + review)

**Contexte :** Phases 0-1 validées (spec + plan). Implémenter nouvelle feature avec workflow 4 phases.

**Actions :**
- [ ] Choisir feature simple-moyenne (< 10 fichiers, 1 migration DB max)
- [ ] Exécuter workflow complet : spec → plan → implémentation → review
- [ ] Mesurer temps réel vs estimé (valider patterns découverts)
- [ ] Documenter learnings Phase 2-3 (implementation + review)

**Critère succès :** Feature mergeable, workflow 4 phases validé end-to-end, score ≥ 7/10 par phase

**Candidats features :**
- Ajout filtre simple (liste dossiers)
- Export CSV ressource
- Amélioration UX mineure

---

## 📊 Métriques Synthèse

| POC | Sessions | Score Moyen | Status |
|-----|----------|-------------|--------|
| **POC 1 - HAML** | 3 | 7.7/10 | ✅ Skill stable |
| **POC 3 - Bugs** | 1 | 4.7/5 | ✅ Workflow validé |
| **POC 4 - Features** | 2 (spec+plan) | 8.2/10 | ⚠️ Implémentation à valider |

**Définition scores :**
- **8-10/10** : Production-ready (autonomie élevée)
- **5-7/10** : Utilisable (supervision modérée)
- **< 5/10** : Non viable (trop d'interventions)

---

## 🗂️ Backlog (Futur)

**Infrastructure :**
- Scripts worktree automation (create/cleanup)
- Git submodule support (checkout Night Shift dans n'importe quel projet)
- Hook catégorisation sessions (détecte type: refactor, review, spec, bug, etc.)
- Dashboard simple métriques (optionnel)

**Skill kaizen automatisé :**
- Créer skill `/kaizen` pour documenter learnings post-session
- Intégrer avec hook catégorisation (propose kaizen si session intéressante)

**Vision "Émergence POC spontanée" :**
- Hook détecte patterns récurrents dans sessions Claude naturelles
- Propose automatiquement création POC quand pattern répété ≥ 3 fois
- Génère skill initial basé sur sessions capturées
- Plug kaizen automatique sur nouveau skill pour amélioration continue

**Documentation :**
- Guide "Appliquer Night Shift à votre projet"
- Extraction patterns réutilisables

---

## 📁 Références Rapides

**Documents clés :**
- `README.md` - Vision & méthodologie
- `ROADMAP.md` - Ce fichier (état & prochaines étapes)
- `WORKFLOW.md` - Guide pratique POCs

**POCs :**
- `pocs/1-haml/` - Setup + skill HAML migration
- `pocs/3-bugs/` - Setup + skills investigation/implémentation
- `pocs/4-features/` - Setup + templates + patterns + checklists

**Skills :**
- `.claude/skills/haml-migration/` - POC 1 (v3)
- `.claude/skills/investigate-sentry-bug/` - POC 3
- `.claude/skills/fix-sentry-bug/` - POC 3
- `.claude/skills/feature-spec/` - POC 4 Phase 0
- `.claude/skills/feature-plan/` - POC 4 Phase 1
- `.claude/skills/feature-implementation/` - POC 4 Phase 2
- `.claude/skills/feature-review/` - POC 4 Phase 3

---

## 🔄 Template Reprise Session

```markdown
# Contexte
Night Shift - Démonstrateur pipelines de dev avec IA
État : Voir ROADMAP.md section "Ce qui est fait"

# Objectif session
[Choisir dans la roadmap]
- Option 1 : POC 1 - Validation visuelle MCP/screenshot
- Option 2 : POC 3 - Kaizen bugs simples (renforcer autonomie)
- Option 3 : POC 4 - Implémenter nouvelle feature
- Option 4 : Autre (préciser)

# Ce que je veux faire
[Décrire précisément]

# Question
Quelle est la meilleure façon de procéder ?
```

---

**Dernière session :** 2026-03-12
**Accomplissements :**
- Revue complète projet (score 8.8/10)
- Corrections incohérences documentation
- Roadmap simplifiée et actionnaire

**Status :** 3 POCs avec résultats tangibles, documentation cohérente, prêt pour prochaines expérimentations
