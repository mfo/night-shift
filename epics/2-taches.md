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

- **`nightshift autofix`** — pipeline séquentiel : retry system tests → fix specs (`claude -p`) → fix linters (rubocop, herb, apostrophe, yaml) → vérification → diff coloré. Pas de commit/push automatique.
- **`nightshift brief`** — morning brief : actions requises, changements depuis le dernier brief, résumé, suggestion. Auto-lancé sur main à l'attach.
- **Badges combinés** — `🔴💬(1)` au lieu d'un seul emoji, CI rouge prime sur les reviews.
- **PR cache** — `fetch_all_prs_cached()` (60s TTL), évite les appels GitHub dupliqués.
- **Auto-triggers** — autofix lancé automatiquement sur transition vers 🔴 (attach + refresh).

### Guardrails livrés

- Circuit breaker : max 2 autofix par PR par heure (bypass en mode debug)
- Claude -p : allowedTools restrictif (Read, Edit, Bash rspec), max 20 turns
- Spinner avec logs dans `tmp/claude.log`
- Commande claude complète affichée pour visibilité

### Backlog (reporté)

| Feature | Raison |
|---|---|
| Event-driven `gh run watch` | Polling 2min suffisant, watch consomme trop d'API |
| Notifications macOS (`osascript`) | Pas nécessaire tant qu'on est dans tmux |
| State file (`state.json`) | État tmux suffit pour l'instant, à revoir au refacto Rust |

---

## Phase 3 : Cycle de vie complet

### Vision

Nightshift passe d'observateur à gestionnaire du cycle de vie PR :

```
nightshift start <branch>
    ... travail, PR, CI, review ...
    refresh : 💬/⛔ → affiche les review comments dans le pane
    refresh : ✅ → active merge when ready
    refresh : 🗑 → check release → 🚀 (deployed)
nightshift clean <branch>
```

### Nouvelles icônes

| Icône | Signification | Action |
|---|---|---|
| 🚀 | Déployée en prod | Cleanup possible |

### Priorités

| # | Feature | Commande/Trigger | Description |
|---|---|---|---|
| **1** | Créer worktree | `nightshift start <branch>` | `git worktree add` + `tmux new-window` immédiat |
| **2** | Merge when ready | Auto sur ✅ au refresh | `gh pr merge --auto --squash` |
| **3** | Review comments | Auto sur 💬/⛔ au refresh | Afficher review comments + conversation dans le pane |
| **4** | Detect deploy | Auto sur 🗑 au refresh | Checker si `#num` dans une release GitHub → 🚀 |
| **5** | Cleanup worktree | `nightshift clean <branch>` | `git worktree remove` + `tmux kill-window` |

### Backlog (non priorisé)

- **Stacked PRs** : `nightshift stack` / `nightshift restack` — rebase en cascade
- **Autonomie** : `claude -p` headless, Docker isolation, boucle kaizen auto

---

## Phase 4 : Nightshift v2 — Migration Ruby

### Lot 1 : Socle Ruby + parité fonctionnelle ✍️

Spec : `specs/2026-04-18-nightshift-v2-ruby-spec.md`

Migration bash → Ruby : reconciliation loop, Sequel/SQLite, pattern matching, tests unitaires. Parité des 8 commandes.

### Lot 1.5 : Cycle de vie worktree + Skills supervisés (TODO — spec à rédiger)

Fermer la boucle : nightshift gère le cycle de vie complet d'un worktree/PR et peut piloter des skills existants.

- `nightshift open <branch>` : crée worktree + fenêtre tmux + PR draft
- `nightshift close <branch>` : merge/cleanup worktree + kill fenêtre tmux
- **Skill runner** : exécuter un skill Claude Code dans un worktree supervisé
  - Deux skills pilotes : `haml-migration`, `test-optimization`
  - Suivi du run dans `runs` (lock, circuit breaker, résultat)
  - Logs capturés, diff affiché en fin de run
- Réconciliation : détecter quand un skill a terminé, proposer commit/push

### Lot 2 : SupervisedSkill + Eval (TODO — spec à rédiger)

- `SupervisedSkill` : claude -p executor + ollama judge + retry loop
- Eval system : fixtures par skill, baseline scores, régression detection
- Kaizen auto-loop : extraire learnings, améliorer SKILL.md
- Utilise `Store` pour persister jobs, scores, kaizens

### Lot 3 : Event sources + concurrence (TODO — spec à rédiger)

- Multi-source polling (GitHub, Sentry, YWH)
- `Async` gem pour concurrence non-bloquante
- Priority queue pour les events
- `nightshift ingest <source> <url>`

### Lot 4 : Renderer découplé (TODO — spec à rédiger)

- Interface `Renderer` abstraite
- `TmuxRenderer` (actuel)
- `SwiftBridgeRenderer` (Unix socket → app macOS native)
- `StdoutRenderer` (debug/CI)

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
