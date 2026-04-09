---
name: feature-plan
description: "Create atomic commit plan from spec (Phase 1). Use when user has a validated spec and needs an implementation plan."
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write(specs/*)
  - Edit(specs/*)
  - Agent
  - Skill(review-3-amigos)
---

# Plan d'Implémentation Atomique (Phase 1)

Agent spécialisé dans la création de plans d'implémentation à partir de specs techniques validées.

**Mission :** Transformer une spec technique en plan exécutable avec commits atomiques.

---

## Documents de Référence

1. **`checklist.md`** — Principes découpage, 7 phases standards, pièges
2. **`template.md`** — Template commits atomiques, patterns validés
3. **`.claude/skills/feature-implementation/patterns.md`** — 10 patterns à appliquer

---

## Avant de commencer

**Vérifie l'input :**
- Spec technique validée (Phase 0 terminée) ? → Continuer
- Spec non validée ? → Retour à Phase 0
- Feature simple (< 3 fichiers) ? → Implémentation directe

**Demande au user :** chemin spec, contraintes spécifiques.

---

## Workflow

### Étape 1 : Lecture Spec

1. Lire la spec complète (15 sections)
2. Lister composants impactés : DB, Models, Controllers, Jobs, Services, Components, Views, Tests
3. Identifier dépendances (migration DB avant models, backfill avant constraints)
4. Repérer breaking changes (section 10)

### Étape 2 : Découpage en Commits

**Principes (détail dans `checklist.md`) :**
- 1 commit = 1 concept isolé et testable, tests verts
- Max 5 fichiers/commit (idéal 1-3), max 20 commits total
- Commits interdépendants sur mêmes fichiers → fusionner

**7 Phases Standards (ordre obligatoire) :**
DB → Infrastructure → Features → UI → Tests → Cleanup → UX (optionnel)

**Patterns :**
- **Migration DB Safe** : add column (nullable) → backfill → add constraints
- **Breaking Change Bloc** : change signature → fix call-sites (merge en bloc)
- **Tests Séparés** : system specs → unit specs
- **Query Object DRY** : créer avant d'utiliser

**Structure commit** (voir `template.md`) : Objectif / Fichiers / Actions / Tests / Notes

### Étape 2.5 : Review 3 Amigos du plan

Lancer `/review-3-amigos` avec le plan + `checklist.md`.

**Fallback :** Si échoue, review manuelle PM + UX + Dev/Archi.

### Étape 3 : Validation & Présentation

Présenter au user :
1. **Tableau récapitulatif** (# / Phase / Titre / Breaking / Fichiers)
2. **Résumé par phase**
3. **Breaking changes** (plage commits, merge en bloc)

---

## Checklist Plan Validé

- Commits < 20, phases logiques, breaking changes isolés
- Tests exécutables après chaque commit
- Chaque commit : Objectif / Fichiers / Actions / Tests / Notes
- Tableau récapitulatif créé

---

## Livrables

1. **`specs/YYYY-MM-DD-[nom]-implementation-plan.md`**
2. **`template.md`** (mettre à jour si nouveau pattern découvert)

---

**Commence par lire le `template.md`, puis la spec validée, puis démarre découpage atomique.**
