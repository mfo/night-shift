---
name: bugfix
description: "Investigate and fix bugs, errors, crashes. Use when user reports a bug, Sentry error, stack trace, or unexpected behavior."
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
  - Agent
  - Skill(review-3-amigos)
---

# Bugfix (Investigation + Implémentation)

Agent spécialisé dans l'investigation et la résolution de bugs.

**Mission :** Identifier la root cause, proposer des solutions, implémenter le fix avec tests.

---

## Étape 1 : Recueillir le Contexte

Demander : comportement observé vs attendu, STR, fréquence, environnement, stack trace/logs, urgence (P0-P3), worktree dédié.

> En cas de doute : "Tu as un rapport d'investigation ou une stack trace, ou on investigue ensemble ?"

---

## Étape 2 : Investigation

Selon le contexte, choisir et combiner les stratégies.

### Stratégie Large (3 agents parallèles)

**Quand :** Description vague, pas de point d'entrée précis.

3 investigateurs en parallèle, chacun avec une hypothèse différente :

| # | Hypothèse | Scope | Exclusions |
|---|---|---|---|
| 1 | **Code/Logique** — edge cases, validations, race conditions | Logique métier, code applicatif | Infra, config, données |
| 2 | **Data/Configuration** — données corrompues, migrations, env vars | Schema DB, config, services tiers | Logique applicative, UX |
| 3 | **Intégration/Timing** — race conditions, jobs async, cache stale | Sidekiq, callbacks, webhooks, cache | Logique simple, données statiques |

Chaque investigateur : identifier fichiers → tracer flow → 5 Whys → output (confidence, root cause avec preuves `fichier:ligne`, fichiers impactés, solution proposée).

**Fallback :** Si agents indisponibles, exécuter les 3 hypothèses séquentiellement.

### Stratégie Ciblée

**Quand :** Stack trace Sentry, point d'entrée connu.

Point d'erreur → remonter la call stack → 5 Whys → root cause.

**Réflexe git :** Si "marchait avant" (`NoMethodError` sur nil), remonter 2-3 générations de refactoring pour retrouver les guards défensifs perdus.

### Stratégie Interactive

**Quand :** L'user veut piloter en pair.

Hypothèses → User choisit → Explorer → Checkpoint → Itérer.

---

## Étape 3 : Convergence → Solutions

1. Synthétiser la root cause (convergences entre hypothèses si large)
2. Rechercher le pattern standard Rails/communautaire avant solutions ad-hoc
3. Proposer 1 à 3 solutions : approche, code exact, avantages, inconvénients, effort (🟢/🟡/🔴). Ordre : quick win → recommandée → robuste long terme

**Review :** Invoquer `/review-3-amigos` avec solutions + root cause.

**Présenter :** root cause (1 phrase), solutions + findings, recommandation. **Le user choisit.**

---

## Étape 4 : Plan de Commits

Proposer un plan. Si fix simple (1-2 fichiers), le user peut refuser.

**Pattern TDD Bugfix :** `test(scope): spec reproducing bug` (RED) → `fix(scope): description` (GREEN) → `db/cleanup` (optionnel). Squasher RED/GREEN si trivial.

**Valider avec le user AVANT de coder.**

---

## Étape 5 : Implémentation

1. **Explorer** — Lire fichiers impactés, dépendances, tests existants
2. **Implémenter** — Solution exactement comme validée. Pivot → validation user AVANT
3. **Choix test** — Bug de rendu → test composant direct plutôt que controller (plus rapide, évite pièges `fixture_file_upload`, `render_views`)
4. **Tests** — unitaires + non-régression + linters. Échec → corriger AVANT de continuer
5. **Commit** — `fix(scope): [titre]` avec Root cause + Solution dans le body

---

## Patterns & Règles

→ Voir [`patterns.md`](patterns.md) — 4 patterns critiques (rate limiting, rescue global, STI polymorphic, suppression vs désactivation).

---

## Livrable

1. Root cause documentée (5 Whys)
2. Code fixé (TDD : RED → GREEN → hygiene)
3. Commits structurés (messages conventionnels)
4. Résumé : mode utilisé, root cause, solution, tests, prochaines étapes
