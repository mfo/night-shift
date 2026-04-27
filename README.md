# Night Shift — Workflows de développement avec IA

**Statut :** Démonstrateur — Exploration et apprentissage en cours (N=1)

---

## L'idée

Développer sur des projets complexes = tâches répétitives, règles à respecter, charge mentale constante. Peut-on déléguer certaines de ces tâches à un agent IA ?

Pas tout automatiser d'un coup. Juste : choisir UNE tâche, créer un prompt, observer ce qui marche, améliorer, répéter.

## Approche

1. Choisir 1 tâche répétitive
2. Créer un skill (prompt + checklist + patterns)
3. Tester, observer, documenter (kaizen)
4. Améliorer le skill avec les learnings
5. Passer à la tâche suivante

## Projet exemple : demarches-simplifiees.fr

Application Rails, ~30 000 commits, contraintes fortes (RGAA, sécurité, GraphQL).

| POC | Skill | Description |
|---|---|---|
| 1 | `haml-migration` | Migration HAML → ERB |
| 2 | `test-optimization` | Optimisation tests lents |
| 3 | `bugfix` | Investigation + correction bugs |
| 4 | `feature-*` | Workflow features en 4 phases (spec → plan → impl → review) |
| 5 | `harden-*` | Sécurité applicative (pentest → audit → fix) |

## Utiliser un skill

Les skills sont des slash commands. Lancer Claude Code dans le projet cible :

```bash
/haml-migration app/views/path/to/file.html.haml
/test-optimization spec/models/dossier_spec.rb
/bugfix <description ou lien Sentry>
/feature-spec → /feature-plan → /feature-implementation → /feature-review
/harden-pentest <surface d'attaque> → /harden-audit → /harden-fix audits/YYYY-MM-DD-slug-audit.md
```

Après une session : `/kaizen write`. Pour améliorer les skills : `/kaizen synth`.

Review transversale : `/review-3-amigos <spec, plan, ou PR diff>`.

## `bin/nightshift` — Orchestrateur de PRs

Suivre ses PRs depuis son terminal. Les faire avancer sans y penser.

Chaque git worktree = une fenêtre tmux, nommée avec le statut PR en temps réel.

```
  📦 main
  🟢 #12933 cleanup-old-referentiel
  🔴 #12931 cleanup-nature-step3
  ✅ #12930 cleanup-nature-step2
  ⏳ #12929 fix-xss-service-links
  💬 #12811 haml-migration (3)
  🗑 #12173 homogenize-preview
```

### Commandes

```bash
# Session tmux
nightshift attach              # Crée/rattache la session tmux depuis les worktrees
nightshift refresh             # Met à jour les statuts PR sur toutes les fenêtres
nightshift status              # Tableau stdout (sans tmux)
nightshift watch               # Refresh continu (toutes les 2 min)
nightshift auto                # refresh + watch (raccourci)
nightshift brief               # Morning brief : actions requises, changements, suggestions

# CI
nightshift diagnose <pr>       # Diagnostic CI : catégorise les échecs (linter/unit/system/codeql)
nightshift autofix <pr>        # Débloquer la CI : fix linters, fix specs (claude -p), retry system tests
nightshift merge <pr>          # Auto-merge squash via gh

# Worktrees
nightshift open <branch>       # Crée un worktree + fenêtre tmux
nightshift close <branch>      # Supprime worktree, branche, DB test, puis fenêtre tmux

# Backlog (skills auto)
nightshift backlog list [skill]  # Liste les items du backlog
nightshift backlog add <skill> <item>   # Ajoute un item au backlog
nightshift backlog scan <skill>  # Scan le repo et alimente le backlog
nightshift backlog skip <id>     # Marque un item failed comme skipped
nightshift skill-run <skill> <item>  # Lance un skill dans le worktree courant (usage interne)
```

### autofix

Quand une PR est rouge, `autofix` prépare le déblocage **dans le worktree de la PR** (résolu via `Worktree.path_for_branch`) :

1. **System tests** — relance les jobs flaky (1 retry max)
2. **Specs** — délègue le fix à `claude -p` (Read, Edit, rspec — max 20 turns)
3. **Linters** — rubocop -A, herb, apostrophe, yaml (en dernier, nettoie ce que claude a pu casser)
4. **Vérification** — relance les specs et linters pour confirmer
5. **Résumé** — diff coloré des fichiers modifiés

Le commit et le push restent manuels. Se lance automatiquement dans le pane tmux quand une PR passe au rouge.

### Iconographie

| Icône | Signification | Action |
|---|---|---|
| 🔨 | Pas de PR | En construction |
| ⏳ | CI en cours | Attendre |
| 🟢 | CI verte, en review | Attendre review |
| 🔴 | CI rouge | Fixer (autofix) |
| 💬 | Commentaires de review | Lire et adresser |
| ⛔ | Changes requested | Corriger |
| ✅ | Approved | Merger |
| 🗑 | Mergée | Worktree supprimable |
| ⊘ | Fermée | Worktree supprimable |

### Configuration

```bash
export NIGHTSHIFT_REPO=~/dev/mon-projet       # Repo cible (défaut: ~/dev/demarches-simplifiees.fr)
export NIGHTSHIFT_SESSION=nightshift           # Nom de session tmux
export NIGHTSHIFT_WATCH_INTERVAL=120           # Intervalle de refresh en secondes
export NIGHTSHIFT_DEBUG=1                      # Mode debug (verbose, bypass circuit breaker)
```

Dépendances : `tmux`, `gh`, `git`. Optionnel : `claude` (pour autofix specs).

## Structure

```
night-shift/
├── bin/nightshift                     # Orchestrateur tmux (bash)
├── bin/nightshift-rb                  # CLI Ruby (commandes métier)
├── lib/nightshift/                    # Code Ruby
│   ├── cli.rb                         # Dispatch des commandes
│   ├── reconciler.rb                  # Boucle reconciliation PR + skills auto
│   ├── skill_runner.rb                # Lancement claude -p + kaizen auto sur échec
│   ├── worktree.rb                    # Gestion worktrees (create, cleanup, DB, path resolution)
│   ├── store.rb                       # SQLite (backlog, PRs)
│   └── ...
├── .claude/skills/                    # Skills (le livrable principal)
│   ├── haml-migration/                # POC 1
│   ├── test-optimization/             # POC 2
│   ├── bugfix/                        # POC 3
│   ├── feature-spec/                  # POC 4 — Phase 0
│   ├── feature-plan/                  # POC 4 — Phase 1
│   ├── feature-implementation/        # POC 4 — Phase 2
│   ├── feature-review/                # POC 4 — Phase 3
│   ├── harden-pentest/                # POC 5 — Explorer une surface d'attaque
│   ├── harden-audit/                  # POC 5 — Qualifier une faille
│   ├── harden-fix/                    # POC 5 — Corriger une faille (TDD)
│   ├── pr-description/                # Transversal — Génère pr-description.md
│   ├── create-pr/                     # Transversal — Push + gh pr create
│   ├── kaizen/                        # Transversal — write + synth
│   └── review-3-amigos/              # Transversal — Review PM+UX+Dev
│
├── hooks/worktree/post-checkout       # Hook : DB isolée + copie .claude/ dans les worktrees
├── epics/                             # Vision et roadmap
├── pocs/                              # Data projet par POC (setup, specs, inventaires)
├── audits/                            # Fichiers d'audit sécurité (contrat harden-audit → harden-fix)
├── kaizen/                            # Learnings par itération
├── specs/                             # Specs techniques ponctuelles
└── docs/                              # Diagrammes (reconciler.mmd)
```

Chaque POC a un numéro aligné entre skills, pocs/ et kaizen/ (ex: `2-test-optimization`).

---

*On ne construit pas un outil, on apprend à construire des workflows. L'échec fait partie du processus.*
