# Epic 2 : Orchestrateur Night Shift

**Status :** En cours — Phase 1 livrée, Phase 1.5 livrée, Phase 2 prête à implémenter

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

## Phase 2 : CI Reactor (prêt à implémenter)

### Concept

Un agent réactif qui gère le cycle CI pour toutes les PRs ouvertes. Le `diagnose` fait le triage, le reactor exécute la réaction.

```
CI rouge → diagnose (Phase 1.5)
  → SI linter only     → autofix + commit + push (automatique)
  → SI system test     → retry 1x (gh run rerun --job)
  → SI system test 2x  → notification "vrai bug"
  → SI unit test       → notification + contexte pré-chargé
  → SI CodeQL          → notification sécurité — escalade humain
```

### Priorités d'implémentation

| Priorité | Feature | Effort | Gain estimé |
|---|---|---|---|
| **P0** | `nightshift autofix` — linters | 2-3h | ~30-40% des CI rouges éliminés |
| **P1** | Retry system tests flaky (1 retry max) | 1h | Faux positifs éliminés |
| **P2** | `gh run watch` par fenêtre (event-driven) | 2h | Réaction en 5-10s au lieu de 0-120s |
| **P3** | Notifications macOS (`osascript`) | 1h | Push au lieu de pull |
| **P4** | State file (`~/.nightshift/state.json`) | 2h | Transitions, métriques, circuit breaker |

### P0 : Autofix linters

```bash
cmd_autofix():
  1. diagnose → détecter le type d'échec
  2. si linter only :
     - cd worktree
     - bundle exec rubocop -a
     - bun lint:herb --fix
     - bundle exec rake lint:apostrophe:fix
     - bundle exec rake lint:yaml_newline:fix
  3. si fichiers modifiés :
     - git add + commit "fix(lint): autofix linter offenses"
     - git push
  4. sinon : rien à fixer, problème ailleurs
```

### P1 : Retry system tests

```bash
# Si catégorie == SYSTEM TEST et @retry_count < 1 :
gh run rerun --job $job_id
tmux set-option @retry_count 1
# Si 2e échec : notification, pas de retry
```

### P2 : Event-driven au lieu de polling

Remplacer le polling global par un watcher ciblé par PR active :
```bash
# Pour chaque fenêtre ⏳ (CI running) :
gh run watch <run-id> --exit-status; nightshift refresh
```
Réaction en 5-10s après la fin du CI au lieu de 0-120s.

### Guardrails (avant tout automatisme)

- **Circuit breaker** : max 2 tentatives autofix par PR par heure
- **Sémaphore** : max 1 `claude -p` actif à la fois (si Phase 3)
- **Timeout** : 300s max par opération automatique
- **Dry-run par défaut** pour `claude -p` : proposer le fix, attendre validation
- **Logs structurés** : `~/.nightshift/log/` avec timestamp, action, PR, résultat
- **Métriques** : `~/.nightshift/metrics.jsonl` (append-only) pour mesurer l'impact

---

## Phase 3 : Stacked PRs + Autonomie (backlog)

### Stacked PRs

Pattern récurrent (ex: #12927→#12929→#12930→#12931→#12933). Le coût de rebase en cascade est un multiplicateur de douleur.

```bash
nightshift stack       — visualiser les chaînes de PRs (via depends_on dans le body)
nightshift restack     — rebase en cascade quand une PR parente est mergée
```

- Détection : parser `depends_on: #\d+` dans les descriptions de PR
- Rebase : `git rebase main && git push --force-with-lease` (jamais `--force` nu)
- Alerte dans `refresh` : si une PR parente est mergée, indiquer `↑ rebase needed`

### Morning briefing

```bash
nightshift brief       — résumé au premier attach de la journée
```

### Autonomie

- `claude -p` pour fixer les unit tests (avec `--allowedTools` restrictif)
- Lancement automatique de skills depuis un inventaire (ancien design de queue)
- Docker isolation pour `claude -p` headless
- Boucle kaizen automatique (PR review comments → amélioration skills)

---

## Ce qui a été abandonné

| Élément initial | Raison |
|---|---|
| `queue.json` + `worker.py` | Résolvait le mauvais problème (lancement vs suivi) |
| Swift menu bar app | tmux donne la visibilité gratuitement |
| Ollama/Gemma triage | Overkill pour du polling `gh` |
| launchd scheduling | `nightshift watch` / `gh run watch` suffisent |
| Docker (Phase 1-2) | Reporté en Phase 3, pas bloquant |
| Polling global toutes les 2 min | Remplacé par `gh run watch` event-driven (Phase 2) |
