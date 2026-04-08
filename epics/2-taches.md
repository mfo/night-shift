# Epic 2 : Du POC à la série — Orchestrateur

**Status :** En conception

---

## Objectif

Automatiser l'exécution des skills matures sur leur stock de fichiers, avec un suivi visuel.

## Décisions prises (2026-04-08)

- **Queue unique** : un `queue.json` qui dépile des fichiers un par un, séquentiellement
- **Deux inventaires** : HAML (758 fichiers), test-optim (52 fichiers)
- **Pas de parallélisme** pour le moment
- **Scheduling** : launchd sur macOS — HAML 3x/jour (09h, 13h, 17h), test-optim 1x/nuit (02h)
- **Suivi visuel** : menu bar app Swift (même pattern que `claude-accept-dismiss-with-context`)
- **Isolation** : Docker pour contraindre Claude Code (filesystem, réseau, CPU/RAM)
- **Exécution** : `claude -p` headless avec `--allowedTools` restreint

## Concepts sous-jacents

- **Harness engineering** : un skill = un harness (guide feedforward + sensor feedback + boucle kaizen)
- **Split inference** : Ollama/Gemma local pour le triage (gratuit, ~100ms), Claude Code pour l'exécution (raisonnement long)

## Architecture cible

```
launchd (scheduling)
  → worker.py (pick → exec → validate → PR → next)
    → queue.json (état des tâches)
    → inventory/{haml.txt, test-optim.txt} (stock)
    → Ollama/Gemma (triage léger)
    → Docker (jail)
      → Claude Code headless (exécution du skill)
    → gh CLI (création PR)
  → nightshift-app.swift (menu bar, suivi visuel)
```

## Flow d'une tâche

```
1. Pick    — prochain fichier de l'inventaire pas encore traité
2. Lock    — status = running dans queue.json
3. Exec    — claude -p dans Docker + worktree isolé
4. Check   — tests verts ?
5. PR      — gh pr create
6. Update  — status = done | failed, résultat logué
7. Notify  — menu bar mis à jour, HUD si échec
```

## Gestion des échecs

Pas de retry automatique. Un échec = probablement un problème de skill → kaizen.
L'humain review les failed dans le menu bar et peut retrigger manuellement.

## Questions ouvertes

- Format exact du Dockerfile
- Gestion des tokens/coûts (budget journalier ?)
- Comment remonter les comments de PR review dans la boucle kaizen
- Quand introduire le parallélisme (worktrees multiples)
