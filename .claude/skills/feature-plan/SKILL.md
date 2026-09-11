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
6. Vérifier si des assets visuels existent dans `specs/assets/YYYY-MM-DD-[nom]/` (maquettes UX sauvées en Stage 0). Si oui, les référencer dans la section "Validation Visuelle" du plan pour que Stage 2 les utilise comme baseline de comparaison.

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

### Étape 2-bis : Regroupement en Couches (stacked PRs)

Les commits atomiques sont pour l'auteur. Les **couches** sont pour le reviewer.

**Une couche = une branche = une PR.** Le reviewer relit et approuve chaque couche
indépendamment ; la pile entière est mergée d'un coup.

**Critère unique — le test de la phrase :**

> Écrire, pour chaque couche, une phrase à l'indicatif : *« ce que le reviewer peut vérifier ici »*.
> Si la phrase ne s'écrit pas, la couche n'existe pas → la fusionner avec la suivante.

**Règles de découpage :**

| Règle | Pourquoi |
|---|---|
| Une couche embarque **ses propres tests** | Sinon le reviewer doit approuver du code non testé. C'est le piège #2 de `checklist.md`, hissé au rang de structure |
| **Jamais de couche « Tests »** séparée | Corollaire direct de la règle ci-dessus |
| Une phase à **0 commit** ne produit pas de couche | Cleanup et UX sont souvent vides |
| Un **bloc breaking change** ne traverse jamais une frontière de couche | Reprise de `checklist.md` §3 : sinon une couche est incompréhensible seule |
| Viser **2 à 5 couches**. Au-delà, regrouper | Au-delà de 5, le coût de navigation dépasse le gain de relecture |
| **1 seule couche → pas de pile** | Fallback : `create-pr` classique, workflow inchangé |

⚠️ **Les 7 phases standards sont un ordre de dépendance, pas un gabarit de découpage.**
Mapper mécaniquement 1 phase → 1 couche produit un découpage *horizontal* : une migration invisible,
puis une infra sans usage, puis une UI qui dépend de tout. Chaque PR est plus petite mais aucune
n'est compréhensible seule — l'inverse de l'objectif.

**Nommage :** `feat/<slug>-<n>-<mot>` (le `<n>` donne l'ordre de lecture dans la liste de PR).
**Worktree :** `feat/<slug>` — un seul worktree pour toute la pile (voir Stage 2).

---

### Étape 2.5 : Review 3 Amigos du plan

Lancer `/review-3-amigos` avec le plan + `checklist.md`.

**Fallback :** Si échoue, review manuelle PM + UX + Dev/Archi.

### Étape 3 : Validation & Présentation

Présenter au user :
1. **Tableau récapitulatif** (# / Phase / Titre / Breaking / Fichiers)
2. **Résumé par phase**
3. **Breaking changes** (plage commits, merge en bloc)

---

## Validation Visuelle dans le Plan

Si la spec a une section 14 (Validation Visuelle) et un `visual_assets_path` non null :

1. **Mapper scénarios → commits** : pour chaque scénario de la spec, identifier le commit à partir duquel il est vérifiable
2. **Ajouter des checkpoints visuels** dans le plan : à la fin du commit concerné, noter `📸 Vérifier scenario-N: [description]`
3. **Référencer les baselines** : le plan doit indiquer le chemin `specs/assets/YYYY-MM-DD-[nom]/ux-scenario-N-*.png` pour que Stage 2 sache quoi comparer

Le mapping scénario → commit est porté dans le JSON de sortie (`visual_validation.checkpoints`).

---

## Checklist Plan Validé

- Couches : 2-5 (ou 1 = pas de pile), chacune avec sa phrase « ce que le reviewer peut vérifier ici »
- Aucune couche « Tests » ; chaque couche embarque ses specs
- Commits < 20, phases logiques, breaking changes isolés
- Tests exécutables après chaque commit
- Chaque commit : Objectif / Fichiers / Actions / Tests / Notes
- Tableau récapitulatif créé
- Si changement d'interface : checkpoints visuels mappés aux commits

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
  "plan_path": "specs/YYYY-MM-DD-nom-implementation-plan.md",
  "stack": {
    "trunk": "main",
    "worktree": "feat/nom-feature",
    "layers": [
      {"branch": "feat/nom-feature-1-db", "base": "main", "title": "Tech: ...", "commits": "1-3", "reviewable": "..."},
      {"branch": "feat/nom-feature-2-api", "base": "feat/nom-feature-1-db", "title": "Amelioration: ETQ ...", "commits": "4-7", "reviewable": "..."}
    ]
  },
  "visual_validation": {
    "assets_path": "specs/assets/YYYY-MM-DD-nom/ | null",
    "scenarios": ["scenario 1 description", "scenario 2 description"],
    "checkpoints": [{"commit": 7, "layer": "feat/nom-feature-2-api", "check": "vérifier scenario-1"}]
  }
}
```

- `visual_validation.assets_path` : repris de `visual_assets_path` du JSON de feature-spec. `null` si pas de changement d'interface.
- `visual_validation.scenarios` : liste des scénarios de capture définis dans la spec (section 14).
- `stack.layers[]` : les couches, de bas en haut. `commits` est une **plage de chaînes** (`"1-3"`), même
  typage que `breaking_changes[].commits`. `reviewable` porte la phrase du test de la phrase.
  Une seule entrée = pas de pile. Ce champ est lu par feature-implementation (Stage 2) et feature-review (Stage 3).
- `visual_validation.checkpoints` : à quels commits la validation visuelle doit être exécutée (pas seulement en
  fin d'implémentation). Chaque checkpoint porte désormais sa **couche propriétaire** — Stage 2 en a besoin pour
  committer un `fix(visual)` au bon étage de la pile. Ce champ est lu par feature-implementation (Stage 2).

---

**Commence par lire le `template.md`, puis la spec validée, puis démarre découpage atomique.**
