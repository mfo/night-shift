# Epic 2 : Orchestrateur Night Shift

**Status :** En cours — Phase 1 livrée, Phase 2 en conception

---

## Recentrage (2026-04-11)

Le problème initial (automatiser le lancement de skills sur des inventaires) n'était pas le vrai bottleneck. Le vrai problème : **le context switching et le babysitting post-PR**.

### Diagnostic

```
envie de délivrer
  → nouveau worktree
    → plus de tabs
      → plus de context switching
        → plus de temps sur du bruit (CI rouge, reviews, GitHub)
          → moins de temps pour délivrer
```

L'outillage scale en débit (3-5 Claude en //) mais pas en visibilité. L'info est éclatée entre terminal + GitHub + la tête du développeur.

### Pivot : de "launcher" à "PR babysitter"

L'ancien design (queue.json, worker.py, Docker, Swift menu bar, Ollama triage, launchd) résolvait un problème secondaire (lancer des skills automatiquement). Le nouveau design résout le problème primaire : **réduire le coût cognitif de suivre ce qui tourne**.

---

## Phase 1 : Visibilité — `nightshift` tmux launcher ✅

**Livré :** `bin/nightshift` (commit `0ea6dbc`)

Chaque worktree git = une fenêtre tmux, nommée avec le status PR en temps réel.

```
nightshift attach    — crée/rattache la session tmux (idempotent)
nightshift refresh   — met à jour les noms de fenêtre (1 appel API batch)
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

- 2 appels GitHub API par refresh (pas N+1) : léger (toutes PRs auteur) + riche (PRs ouvertes avec CI/reviews)
- `gh --jq` pour le parsing (zéro dépendance hors `gh`, `git`, `tmux`)
- Metadata stockée dans les user options tmux (`@branch`, `@worktree_path`)
- `allow-rename off` pour que tmux ne surcharge pas les noms

### Reviews (4 experts : tmux, DevOps, SRE, Dev senior)

Retours intégrés dans la v1 :
- ✅ Attach idempotent (pas de `kill-session`)
- ✅ 1 appel batch au lieu de N+1
- ✅ `gh --jq` au lieu de python3 inline
- ✅ `allow-rename off`
- ✅ User options tmux `@branch` / `@worktree_path`
- ✅ Gestion d'erreur explicite (réseau, auth, rate limit)
- ✅ Variables d'env configurables (`NIGHTSHIFT_REPO`, `NIGHTSHIFT_SESSION`, `NIGHTSHIFT_WATCH_INTERVAL`)

---

## Phase 2 : Réactivité — PR Babysitter (en conception)

### Concept

Le `watch` détecte les transitions d'état. Au lieu de juste renommer la fenêtre, il **réagit** :

```
watch détecte: 🟢 → 🔴 (CI vient de casser sur fenêtre 3)
  → tmux split-window -v -t nightshift:3
  → claude -p "lis gh pr checks, récupère le log, fix, push"
  → si fix OK → push → CI relance → fenêtre passe à ⏳
  → si 2 échecs → 🚨 escalade + notif macOS
```

### Pré-requis

1. **Fichier d'état** (`~/.nightshift/state.json`) — pour détecter les transitions (état précédent vs actuel). Sans ça, pas de notion de "ça vient de changer".

2. **Prompts par type de réaction** :
   - CI red → lire le log CI, identifier l'erreur, fixer, push
   - Review comment → lire les commentaires, adresser, push
   - Changes requested → lire la review, corriger, push

3. **Gardes** :
   - Pas de babysit sur 🔨 (pas de PR)
   - Pas de babysit si humain actif dans la fenêtre
   - Max 2 tentatives avant escalade
   - Notification macOS (`osascript`) sur escalade et merge

### Scope MVP

Commencer par **CI red seulement**. Le plus fréquent, le plus mécanique, le plus facile à valider (la CI repasse verte ou pas).

### Questions ouvertes

- `claude -p` dans un split pane (visible) ou en background ?
- Comment détecter si l'humain est actif dans une fenêtre ? (`tmux display-message -p '#{window_active}'`)
- Budget tokens : limiter à N babysits par jour ?
- Docker pour isoler les `claude -p` headless (Phase 3 ?)

---

## Phase 3 : Autonomie (backlog)

- Lancement automatique de skills depuis un inventaire (l'ancien design de queue)
- Docker isolation pour `claude -p` headless
- Budget management (tokens/jour)
- Boucle kaizen automatique (PR review comments → amélioration skills)

---

## Ce qui a été abandonné

| Élément initial | Raison |
|---|---|
| `queue.json` + `worker.py` | Résolvait le mauvais problème (lancement vs suivi) |
| Swift menu bar app | tmux donne la visibilité gratuitement |
| Ollama/Gemma triage | Overkill pour du polling `gh` |
| launchd scheduling | `nightshift watch` suffit pour le moment |
| Docker (Phase 1) | Reporté en Phase 3, pas bloquant pour le babysitter |
