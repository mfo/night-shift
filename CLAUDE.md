# CLAUDE.md — Night Shift

Ce projet est un **méta-projet** : il contient des skills, templates et workflows pour Claude Code. Ce n'est pas une application — c'est une chaîne de production logicielle.

## Architecture

Le harness Ruby (`lib/nightshift/`) est organisé en 6 modules Zeitwerk :

| Module | Responsabilité |
|---|---|
| `Core` | Données et persistance — `Store` (SQLite), `PR`, `BacklogItem`, `AutolearnCycle` |
| `CI` | Intelligence post-CI — `Judge` (verdict LLM), `Verdict`, `Autofix`, `Reprioritizer` |
| `Skills` | Exécution des skills — `Runner` (appel `claude -p`), `RunnerResult`, `Pipeline` (run→PR ou judge→retry), `Loader` |
| `Integrations` | Monde extérieur — `GitHub` (API gh), `Worktree` (git worktrees), `N1Scanner` |
| `Monitoring` | Observabilité — `AutolearnMonitor`, `Brief`, `Diagnose` |
| `UI` | Affichage tmux — `TmuxRenderer`, `Attach` |

Modules transversaux hors namespace : `CLI` (Thor), `Reconciler` (boucle principale), `Log` (logger structuré).

### Flux de données principal

```
Reconciler.reconcile(prs)
  ├─ PR lifecycle : fetch → upsert → state transition → renderer action
  └─ Skill pipeline : pick_next → launch_skill → Runner.run
       ├─ succès → Pipeline.execute → push + gh pr create → pr_open
       └─ échec → Judge.evaluate → Verdict
            ├─ retryable → patch patterns.md + reset pending
            └─ non retryable → skip
```

### Contrats typés (T::Struct)

Les modules communiquent via 4 structs Sorbet immutables :

| Struct | Produit par | Consommé par |
|---|---|---|
| `Core::BacklogItem` | `Store.claim_next`, `Store.all_backlog`, etc. | `CLI`, `Reconciler`, `Pipeline` |
| `Core::AutolearnCycle` | `Store.cycles_for_item` | `CLI` (inspect), `AutolearnMonitor` |
| `CI::Verdict` | `Judge.evaluate` | `Pipeline.handle_failure` |
| `Skills::RunnerResult` | `Runner.run` | `Pipeline.execute` |

Les rows SQLite brutes (hashes Sequel) sont converties via `BacklogItem.from_row(row)` et `AutolearnCycle.from_row(row)` dans le Store. En aval, tout le code utilise la notation `.field` (pas `[:field]`).

### CLI (Thor)

Chaque groupe de commandes est dans son fichier (`lib/nightshift/cli/<groupe>.rb`).

```
CLI < Thor                              # cli.rb — squelette
  ├── attach                            # Point d'entrée (crée/rattache session tmux)
  ├── watch, skill_run                  # Interne (lancés dans les panes tmux)
  ├── pr (subcommand)                   # cli/pr.rb
  │     ├── merge, brief, diagnose, autofix
  ├── worktree (subcommand)             # cli/worktree.rb
  │     ├── open, close, reset
  ├── autolearn (subcommand)            # cli/autolearn.rb
  │     ├── status, report, inspect
  └── backlog (subcommand)              # cli/backlog.rb
        ├── add, scan, list, skip, retry
```

## Structure des Skills

Chaque skill vit dans `.claude/skills/<nom>/` avec :
- `SKILL.md` — le prompt principal (frontmatter obligatoire : `name` + `description`)
- `checklist.md` — grille de validation (optionnel)
- `template.md` — template de livrable (optionnel)
- `patterns.md` — patterns validés (optionnel, auto-patché par autolearn)

## Règles

- **Références croisées** : quand tu déplaces ou renommes un fichier, mets à jour TOUTES les références dans les autres fichiers. Utilise `grep -r "ancien-nom"` pour les trouver.
- **Nommage générique** : pas de noms spécifiques à un outil externe dans les noms de skills (ex: `bugfix` pas `fix-sentry-bug`). Le contenu peut mentionner des outils spécifiques, pas le nom.
- **Pas de GPG sign** : utiliser `--no-gpg-sign` pour les commits.
- **Kaizen** : les retours d'expérience vont dans `kaizen/<catégorie>/iteration-N/`. Toujours extraire les learnings pour améliorer les skills.
- **DRY entre skills** : si un pattern se répète dans 2+ skills, l'extraire dans un skill réutilisable (ex: `review-3-amigos`).
- **Solution minimale d'abord** : ne pas sur-engineer. Proposer le fix le plus simple, laisser le user complexifier.

## Tests

```bash
bundle exec ruby -Ilib -Itest test/*_test.rb   # Tous les tests
bundle exec ruby -Ilib -Itest test/judge_test.rb  # Un fichier
```

Tests dans `test/` — Minitest, pas de fixtures externes. Les tests créent une DB SQLite in-memory.
