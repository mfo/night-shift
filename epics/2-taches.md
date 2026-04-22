# Epic 2 : Orchestrateur Night Shift

**Status :** En cours — Phase 1 ✅, Phase 1.5 ✅, Phase 2 ✅, Phase 3 en cours

---

## Contexte terrain

Le goulet actuel : **le babysitting post-PR** (CI rouge, reviews, context switching entre worktrees, rebases de stacked PRs).

## Recentrage (2026-04-11)

L'ancien design (queue.json, worker.py, Docker, Swift menu bar, Ollama triage, launchd) résolvait un problème secondaire (lancer des skills automatiquement). Le nouveau design résout le problème primaire : **réduire le coût cognitif de suivre ce qui tourne**.

```
envie de délivrer → nouveau worktree → plus de tabs → plus de context switching
  → plus de temps sur du bruit (CI rouge, reviews, GitHub) → moins de temps pour délivrer
```

---

## Phase 1 : Visibilité — `nightshift` tmux launcher ✅

**Livré :** `bin/nightshift`

Chaque worktree git = une fenêtre tmux, nommée avec le status PR en temps réel.

```
nightshift attach    — crée/rattache la session tmux (idempotent)
nightshift refresh   — met à jour les noms de fenêtre (2 appels API batch)
nightshift status    — tableau stdout
nightshift watch     — refresh continu toutes les 2 min
```

### Iconographie

| Icône | Signification | Action |
|---|---|---|
| 🔨 | Pas de PR | En cours de construction |
| ⏳ | CI running | Attendre |
| 🟢 | CI green, en review | Attendre review |
| 🔴 | CI rouge | Fixer |
| 💬 | Review comments | Lire et adresser |
| ⛔ | Changes requested | Corriger |
| ✅ | Approved | Merger |
| 🗑 | Merged | Worktree supprimable |
| ⊘ | Closed | Worktree supprimable |

### Architecture

- 2 appels GitHub API par refresh (pas N+1) : léger `--state all` (toutes PRs auteur) + riche `--state open` (CI/reviews)
- `gh --jq` pour le parsing (zéro dépendance hors `gh`, `git`, `tmux`)
- Metadata stockée dans les user options tmux (`@branch`, `@worktree_path`)
- `allow-rename off` pour que tmux ne surcharge pas les noms
- Variables d'env configurables (`NIGHTSHIFT_REPO`, `NIGHTSHIFT_SESSION`, `NIGHTSHIFT_WATCH_INTERVAL`)

---

## Phase 1.5 : Diagnostic — `nightshift diagnose` ✅

**Livré :** commande `diagnose` dans `bin/nightshift`

Quand une PR est 🔴, récupère les logs CI et affiche un diagnostic catégorisé directement dans le pane tmux.

```
nightshift diagnose [repo-path] [pr-number]
```

### Matrice de réaction CI

| Check CI | Catégorie | Diagnostic | Action recommandée |
|---|---|---|---|
| **Linters** | 🧹 LINTER | Fichier:ligne + offense | `rubocop -a`, `bun lint:herb --fix` |
| **Unit tests** | 🧪 UNIT TEST | Specs en erreur + Failure/Error | Fix manuel ou Claude |
| **System tests** | 🧪 SYSTEM TEST | Specs en erreur | `gh run rerun --job <id>` (flaky) |
| **CodeQL** | 🔒 SECURITY | Alerte | Review manuelle — escalade |

### Fonctionnement

- `gh api repos/.../actions/jobs/<id>/logs` pour récupérer les logs bruts
- Parsing : `grep` sur `rspec ./spec/`, `Failure/Error`, `offense`, `examples.*failure`
- Catégorisation automatique par nom de job CI
- **Auto-diagnose** : se lance automatiquement dans le pane tmux au `attach` (fenêtres 🔴) et au `refresh` (transition vers 🔴)

### Reviews (3 experts : Staff Engineer, DevOps Lead, Dev Tooling)

Retours intégrés, basés sur l'analyse des 64 PRs produites :
- ✅ Le tooling est un multiplicateur (10 PRs/semaine), pas du méta-travail
- ✅ Le diagnose catégorisé est le bon pré-requis avant l'automatisation
- ✅ L'auto-diagnose au attach + sur transition est le bon UX

---

## Phase 2 : CI Reactor ✅

### Livré

- **`nightshift autofix <pr>`** — pipeline séquentiel : retry system tests → fix specs (`claude -p`) → fix linters (rubocop, herb, apostrophe, yaml) → vérification → diff coloré. Pas de commit/push automatique.
- **`nightshift brief`** — morning brief : actions requises, changements depuis le dernier brief, suggestions. Auto-lancé sur main à l'attach.
- **`nightshift merge <pr>`** — auto-merge squash via `gh pr merge --auto --squash`
- **Badges combinés** — `🔴💬(1)` au lieu d'un seul emoji, CI rouge prime sur les reviews.
- **Auto-triggers** — autofix lancé automatiquement sur transition vers 🔴 (attach + refresh).

### Guardrails livrés

- Circuit breaker : max 2 autofix par PR par heure
- Claude -p : allowedTools restrictif (Read, Edit, Bash rspec), max 20 turns
- Logs dans `tmp/claude.log`

### Reporté

| Feature | Raison |
|---|---|
| Event-driven `gh run watch` | Polling 2min suffisant, watch consomme trop d'API |
| Notifications macOS (`osascript`) | Pas nécessaire tant qu'on est dans tmux |
| State file (`state.json`) | SQLite remplace, à revoir au refacto Rust |

---

## Phase 3 : Skills auto + Worktree lifecycle (en cours)

### Livré

- **Backlog SQLite** — `backlog add/scan/list/skip`, lifecycle pending → running → pr_open → done/failed
- **Reconciler** — boucle de réconciliation : PR merged → cleanup, zombie recovery, pick next item
- **SkillRunner** — lance `claude -p` avec invocation naturelle du skill, `--permission-mode acceptEdits`
- **Worktree lifecycle** — `open`, `close` avec `Worktree.cleanup` (supprime worktree, branche, DB test)
- **Post-checkout hook** — DB isolée par worktree, copie `.claude/` depuis night-shift (sans agents)
- **Short slugs** — noms de worktree lisibles et compatibles PostgreSQL (63 chars)
- **Auto kaizen sur échec** — `analyze_failure` lit le log et écrit un kaizen
- **Guard file_not_found** — skip automatique si le fichier cible n'existe plus sur main

### En cours

- Premier run complet haml-migration + test-optimization en mode auto
- Stabilisation des permissions (allowed-tools dans les skills)

### Backlog

| Feature | Description |
|---|---|
| Stacked PRs | `nightshift stack/restack` — rebase en cascade |
| Early-exit permission denied | Kill le process après N denials (sans thread) |
| Autonomous debug loop | Spec dans `specs/autonomous-debug.md` |
| Auto-eval | Spec dans `specs/autoeval-todo.md` |

---

## Ce qui a été abandonné

| Élément initial | Raison |
|---|---|
| `queue.json` + `worker.py` | Résolvait le mauvais problème (lancement vs suivi) |
| Swift menu bar app | tmux donne la visibilité gratuitement |
| Ollama/Gemma triage | Overkill pour du polling `gh` |
| launchd scheduling | `nightshift watch` / `gh run watch` suffisent |
| Docker (Phase 1-2) | Reporté en Phase 3, pas bloquant |
| Polling global toutes les 2 min | Polling 2min suffisant, `gh run watch` consomme trop d'API |
