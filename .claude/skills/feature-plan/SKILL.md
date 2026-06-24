---
name: feature-plan
description: "Create atomic commit plan from spec (Stage 1). Use when user has a validated spec and needs an implementation plan."
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write(specs/*)
  - Edit(specs/*)
  - Agent
  - Skill(review-3-amigos)
---

# Plan d'Implémentation Atomique (Stage 1)

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
- Spec technique validée (Stage 0 terminée) ? → Continuer
- Spec non validée ? → Retour à Stage 0
- Feature simple (< 3 fichiers) ? → Implémentation directe

**Demande au user :** chemin spec, contraintes spécifiques.

---

## Workflow

### Étape 1 : Lecture Spec

1. Auto-découvrir la spec : `Glob("specs/*-spec.md")` — prendre la plus récente si plusieurs
2. Lire la spec complète (16 sections)
3. Lister composants impactés : DB, Models, Controllers, Jobs, Services, Components, Views, Tests
4. Identifier dépendances (migration DB avant models, backfill avant constraints)
5. Repérer breaking changes (section 10)

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

## Handoff Stage 2

Une fois le plan validé par le user :
1. Marquer le Status comme `Validated` dans le frontmatter du plan
2. Indiquer au user de lancer `/feature-implementation` (Stage 2)
3. Si une **Issue Source** est dans la spec → la reporter dans le plan pour le mode adversarial en Stage 3

---

## Output Structuré

Terminer le skill par un bloc JSON dans un code fence. Le harness valide la présence des champs requis.

```json
{
  "status": "draft_v1 | validated",
  "issue_source": "https://github.com/... | null",
  "commits_count": 12,
  "breaking_changes": [{"commits": "4-6", "description": "..."}],
  "plan_path": "specs/YYYY-MM-DD-nom-implementation-plan.md"
}
```

---

**Commence par lire le `template.md`, puis la spec validée, puis démarre découpage atomique.**
