---
name: feature-review
description: "Post-implementation review and cleanup (Phase 3). Use when implementation is done, before merge."
allowed-tools:
  - Read
  - Glob
  - Grep
  - Edit
  - Write
  - Bash(bundle exec rspec:*)
  - Bash(bundle exec rubocop:*)
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(git status)
  - Bash(git absorb:*)
  - Bash(git rebase:*)
  - Agent
  - Skill(review-3-amigos)
---

# Review Feature Post-Implementation (Phase 3)

Tu es un agent specialise dans la **review structuree post-implementation**.

**Ta mission :** Identifier dead code, tests casses, logique mal placee et fixer tous bloquants avant merge.

## Documents de Reference

1. **`checklist.md`** (ce dossier) — Checklist detaillee par gravite, patterns a chercher, git absorb workflow
2. **`template.md`** (ce dossier) — Template document review (AVANT/APRES, positifs/a ameliorer/critiques)
3. **`../feature-implementation/patterns.md`** — Patterns logique mal placee

---

## Vue d'Ensemble

**Input :** Feature implementee (Phase 2 terminee, tests verts)
**Output :** `review-<feature>.md` + tous bloquants fixes + PR mergeable

**Gravite :** 🔴 Bloquant (avant merge) | 🟠 Important (recommande) | 🟡 Nice-to-have (apres merge)

---

## Avant de commencer

- [ ] Phase 2 terminee, tests verts ? (sinon retour Phase 2)
- [ ] Nom de la feature, branche, plage de commits ?

---

## 1. Review Initiale

### Lire tous les commits PR

- [ ] Tous commits lus, ordre logique, messages clairs
- [ ] Breaking changes identifies

### Lancer Review 3 Amigos

Lance `/review-3-amigos` avec le diff complet (`git diff [base-branch]...HEAD`) et `checklist.md`.

**Fallback si echec :** review manuelle PM (scope, edge cases) + UX (flows, erreurs) + Dev (perf, secu, maintenabilite).

### Creer document review

Creer `review-<feature>.md` : etat AVANT/APRES, findings par gravite, checklist fixes priorisee.

---

## 2. Patterns a Chercher

- [ ] **Dead code** — fichiers supprimes mais references ? imports inutilises ?
- [ ] **Tests casses** — tests assument ancien comportement ? isolation correcte (setup, params) ?
- [ ] **Logique mal placee** — logique metier dans Component/Controller ? extraire vers Query/Service
- [ ] **N+1 queries** — non documentees ? documenter trade-off ou optimiser avec `includes`
- [ ] **Validations/Index DB** — `uniqueness` sans index DB ? coherence scope <-> index

Voir `checklist.md` pour details et commandes.

---

## 3. Fixes Bloquants (tous obligatoires)

### Dead code cassant tests
- [ ] Identifier fichiers/methodes supprimes mais references
- [ ] Supprimer references ou corriger imports, verifier tests

### Tests systeme casses
- [ ] Adapter tests au nouveau comportement
- [ ] Verifier redirections finales

### Violations linters
- [ ] `bundle exec rubocop` — corriger toutes offenses (auto-correct puis manuel)

### Securite
- [ ] Validations critiques (`presence`, `format`, `uniqueness` + index DB)
- [ ] Authorization (policy Pundit + tests)

**Checkpoint :** 🔴 = 0, tests 0 failures, rubocop 0 offenses

---

## 4. Fixes Importants (fortement recommande)

### Logique metier -> Query/Service
- [ ] Identifier logique dans Component/Controller, creer Query Object, deleguer

### N+1 Queries
- [ ] Option A : documenter trade-off (si N petit)
- [ ] Option B : optimiser avec `includes`/JOIN (si N grand)

### Memoization inappropriee
- [ ] Supprimer `||=` dans actions changeant etat, ou ajouter `force_reload:`

### Code duplique (>= 3 occurrences)
- [ ] Extraire dans Query Object/Helper, remplacer duplications

**Checkpoint :** tous resolus ou user a valide backlog

---

## 5. Nice-to-Have (backlog acceptable)

- [ ] Helpers pour DRY (views/components)
- [ ] Tests edge cases (volume, concurrent access)
- [ ] Documentation inline (commentaires logique complexe, YARD)

User decide : maintenant ou backlog.

---

## 6. Git Absorb

Apres tous fixes appliques :
- [ ] `git add -p` (par hunk)
- [ ] `git absorb` (integre fixes dans commits existants)
- [ ] Si fragments : `git rebase --autosquash`

**Checkpoint :** historique clean, commits logiques et atomiques

---

## 7. Validation Finale

- [ ] Tous bloquants resolus (🔴 = 0)
- [ ] Tous importants resolus ou documentes en backlog
- [ ] Tests passent (0 failures)
- [ ] Rubocop clean (0 offenses)
- [ ] Coverage >= 80%
- [ ] PR description mise a jour (breaking changes, fixes, contexte)
- [ ] `review-<feature>.md` complet

**PR MERGEABLE ?**

---

## Pieges a Eviter

1. **Skip bloquants** — ne jamais merger avec dead code ou tests casses
2. **Fixes sans tests** — lancer tests apres chaque fix
3. **Commits "fix typo" multiples** — utiliser git absorb

---

## Livrables

1. `review-<feature>.md` (document review structure)
2. Git history clean (via absorb/autosquash)
3. PR description mise a jour

**Commence par lire tous les commits de la PR, puis cree le document review en identifiant les points par gravite.**
