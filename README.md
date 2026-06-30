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
| 6 | `i18n-hardcoded` | Extraction strings FR en dur → i18n YAML |
| 7 | `n1-query-fix` | Fix N+1 queries (Prosopite + Skylight) |
| 8 | `flaky-test-fix` | Fix specs flaky (merge queue + retry detection) |

## Utiliser un skill

Les skills sont des slash commands. Lancer Claude Code dans le projet cible :

```bash
/haml-migration app/views/path/to/file.html.haml
/test-optimization spec/models/dossier_spec.rb
/bugfix <description ou lien Sentry>
/feature-spec → /feature-plan → /feature-implementation → /feature-review
/harden-pentest <surface d'attaque> → /harden-audit → /harden-fix audits/YYYY-MM-DD-slug-audit.md
/n1-query-fix app/controllers/users/dossiers_controller.rb
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
# Session
nightshift --repo ~/dev/mon-projet attach   # Crée/rattache la session tmux + lance le watch

# PR lifecycle
nightshift pr merge <pr>       # Auto-merge squash via gh
nightshift pr brief            # Morning brief : actions requises, changements, suggestions
nightshift pr diagnose <pr>    # Diagnostic CI : catégorise les échecs (linter/unit/system/codeql)
nightshift pr autofix <pr>     # Débloquer la CI : fix linters, fix specs (claude -p), retry system tests

# Worktrees
nightshift worktree open <branch>   # Crée un worktree + fenêtre tmux
nightshift worktree close <branch>  # Supprime worktree, branche, DB test, puis fenêtre tmux
nightshift worktree reset <skill>   # Reset items running/failed → pending (cleanup worktrees)

# Backlog (skills auto)
nightshift backlog list [skill]         # Liste les items du backlog
nightshift backlog add <skill> <item>   # Ajoute un item au backlog
nightshift backlog scan <skill>         # Scan le repo et alimente le backlog
nightshift backlog skip <id>            # Marque un item failed comme skipped
nightshift backlog retry <id>           # Remet un item failed/skipped en pending (reset retries)

# Autolearn monitoring
nightshift autolearn status [skill]   # Dashboard cycles par skill
nightshift autolearn report           # Rapport 24h : verdicts, patches, suggestions
nightshift autolearn inspect <id>     # Histoire complète d'un item : cycles, verdicts, patches
```

### autofix

Quand une PR est rouge, `autofix` prépare le déblocage **dans le worktree de la PR** (résolu via `Worktree.path_for_branch`) :

1. **System tests** — relance les jobs flaky (1 retry max)
2. **Specs** — délègue le fix à `claude -p` (Read, Edit, rspec — max 20 turns)
3. **Linters** — rubocop -A, herb, apostrophe, yaml (en dernier, nettoie ce que claude a pu casser)
4. **Vérification** — relance les specs et linters pour confirmer
5. **Résumé** — diff coloré des fichiers modifiés

Le commit et le push restent manuels. Se lance automatiquement dans le pane tmux quand une PR passe au rouge.

### autolearn — Boucle auto-améliorante

Quand un skill échoue en mode auto, un **juge LLM** analyse l'échec et décide de la suite. Si le skill est en cause, il patche `patterns.md` et relance. Le skill s'améliore au fil des échecs.

```
Reconciler (watch 120s)
  └─ pick_next_items → launch_skill
       └─ SkillRunner.run (claude -p)
            ├─ succès → git push + gh pr create → pr_open
            └─ échec → Judge.evaluate
                 ├─ skill_defect → patch patterns.md + retry
                 ├─ infra_error → retry sans patch
                 ├─ item_hard → skip
                 └─ context_limit → skip
```

**Verdicts du juge :**

| Verdict | Action |
|---|---|
| `skill_defect` | Patch `patterns.md` + retry (le prompt manque une instruction) |
| `infra_error` | Retry sans patch (serveur, DB, réseau) |
| `item_hard` | Skip (item trop complexe pour le skill) |
| `context_limit` | Skip (max turns atteint sans convergence) |

**Garde-fous :**

- Max 3 retries par item
- Seul `patterns.md` est modifié (SKILL.md = constitution, read-only)
- Cap de 5 auto-pitfalls avant review humaine (`kaizen synth`)
- Pas de patch si confiance du juge < 0.5
- Chaque patch est un commit git (rollback possible)

Chaque cycle est tracé en SQLite (`autolearn_cycles`). Consulter avec `autolearn-status` et `autolearn-report`.

Documentation détaillée : [`docs/autolearn.md`](docs/autolearn.md)

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

Le repo cible contient un `.nightshift.yml` (config des skills) et `.nightshift/nightshift.db` (état local, auto-créé). Voir [`config/nightshift.yml`](config/nightshift.yml) pour un exemple commenté.

```yaml
# .nightshift.yml — dans le repo cible
backends:
  local:
    harness: claude-ds4    # binary à exécuter
    concurrency: 1         # max items running en parallèle sur ce backend
  frontier:
    harness: claude
    concurrency: 4

default_backend: local

skills:
  haml-migration:
    needs_server: true     # lance overmind avant le skill
    port: 3210
    # backend: frontier    # override le backend par défaut
  test-optimization: {}
  i18n-hardcoded:
    batch_size: 5          # traite N items par worktree
```

**Backends & concurrence :** chaque backend définit un binaire (`harness`) et un plafond de concurrence. Le reconciler compte les items `running` par harness et ne lance de nouveaux items que si `active < concurrency`. Ceci permet de faire cohabiter un modèle local (concurrency: 1) et une API frontier (concurrency: 4). Par défaut, 1 seul item actif par skill (`active_for_skill?`), plus le plafond backend.

**BacklogSources :** la logique de scan, filtrage et priorité est dans le code Ruby (`lib/nightshift/backlog_sources/`), pas dans le YAML. Le YAML ne définit que les propriétés runtime (server, port, batch_size, backend).

```bash
# Flag obligatoire
nightshift --repo ~/dev/mon-projet attach

# Variables d'environnement (.env dans le repo night-shift)
export NIGHTSHIFT_SESSION=nightshift           # Nom de session tmux
export NIGHTSHIFT_WATCH_INTERVAL=120           # Intervalle de refresh en secondes
export NIGHTSHIFT_USER=mfo                     # Utilisateur GitHub (filtrage PRs)
export NIGHTSHIFT_AUTOFIX_MAX=3                # Autofix max par PR par fenêtre
export NIGHTSHIFT_AUTOFIX_WINDOW=3600          # Fenêtre autofix en secondes
```

Dépendances : `tmux`, `gh`, `git`. Optionnel : `claude` (pour autofix specs et skills auto).

### Budget IA

Plan Claude Max (forfait mensuel). Pas de facturation au token — au pire, rate limit.

### Goulet d'étranglement

La review d'équipe, pas la production de PRs. Le pipeline est limité à **1 PR par skill** tant que la PR en cours n'est pas approved/merged (`active_for_skill?` bloque sur `pr_open`). Pas de flood de PRs la nuit.

## Structure

```
night-shift/
├── bin/nightshift                     # Orchestrateur tmux (bash)
├── bin/nightshift-rb                  # CLI Ruby (commandes métier)
├── config/nightshift.yml              # Référence .nightshift.yml (à copier dans le repo cible)
├── lib/nightshift/                    # Harness Ruby (Zeitwerk autoloaded)
│   ├── config.rb                      # Chargement .nightshift.yml (skills, DB path)
│   ├── cli.rb                         # CLI Thor — squelette + daemon + subcommands
│   ├── cli/                           # Subcommands Thor (1 fichier = 1 groupe)
│   │   ├── backlog.rb                 # nightshift backlog {add,scan,list,skip,retry}
│   │   ├── pr.rb                      # nightshift pr {merge,brief,diagnose,autofix}
│   │   ├── worktree.rb                # nightshift worktree {open,close,reset}
│   │   └── autolearn.rb              # nightshift autolearn {status,report,inspect}
│   ├── reconciler.rb                  # Boucle reconciliation PR + skills auto
│   ├── log.rb                         # Logger structuré (niveaux via NIGHTSHIFT_LOG_LEVEL)
│   ├── core/                          # Données et persistance
│   │   ├── store.rb                   # SQLite (backlog, PRs, autolearn_cycles)
│   │   ├── pr.rb                      # PR state machine (STATES, EMOJI, state derivation)
│   │   ├── backlog_item.rb            # T::Struct — item du backlog (typé)
│   │   └── autolearn_cycle.rb         # T::Struct — cycle autolearn (typé)
│   ├── ci/                            # Intelligence post-CI
│   │   ├── judge.rb                   # Juge LLM post-échec (verdict + patch suggestion)
│   │   ├── verdict.rb                 # T::Struct — verdict du juge (typé)
│   │   ├── autofix.rb                 # Auto-fix CI (linters, specs, retry flaky)
│   │   └── reprioritizer.rb           # Repriorisation dynamique du backlog
│   ├── skills/                        # Exécution des skills
│   │   ├── runner.rb                  # Lancement claude -p (exécution brute)
│   │   ├── runner_result.rb           # T::Struct — résultat du runner (typé)
│   │   ├── pipeline.rb                # Pipeline complet : run → PR ou judge → retry
│   │   └── loader.rb                  # Chargement SKILL.md + parsing frontmatter
│   ├── backlog_sources.rb              # Registry BacklogSources.for(skill, repo)
│   ├── backlog_sources/               # Scan, filtre, priorité par skill
│   │   ├── base.rb                    # Classe abstraite (scan/relevant?/prioritize)
│   │   ├── haml_migration.rb          # Glob .haml (views + components)
│   │   ├── i18n_hardcoded.rb          # Glob + filtre Nokogiri (texte FR en dur)
│   │   ├── test_optimization.rb       # Glob specs + priorité par durée (rspec_profile.json)
│   │   ├── n1_query_fix.rb            # Prosopite logs + Skylight (waste_ms)
│   │   └── flaky_test_fix.rb          # GitHub Actions API (merge queue + retry)
│   ├── integrations/                  # Monde extérieur
│   │   ├── github.rb                  # API gh (fetch PRs, comments)
│   │   └── worktree.rb                # Gestion git worktrees (create, cleanup)
│   ├── monitoring/                    # Observabilité
│   │   ├── autolearn_monitor.rb       # Dashboard et rapport autolearn
│   │   ├── brief.rb                   # Morning brief (PRs ouvertes)
│   │   └── diagnose.rb                # Diagnostic CI
│   └── ui/                            # Affichage tmux
│       ├── tmux_renderer.rb           # Rendu fenêtres tmux (rename, menus, panes)
│       └── attach.rb                  # Création/rattachement session tmux
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
│   ├── i18n-hardcoded/                # POC 6 — Extraction strings FR → i18n YAML
│   ├── n1-query-fix/                  # POC 7 — Fix N+1 queries (Prosopite + Skylight)
│   ├── flaky-test-fix/                # POC 8 — Fix specs flaky (merge queue + retry)
│   ├── pr-description/                # Transversal — Génère pr-description.md
│   ├── create-pr/                     # Transversal — Push + gh pr create
│   ├── kaizen/                        # Transversal — write + synth
│   ├── review-3-amigos/              # Transversal — Review PM+UX+Dev
│   ├── til/                           # Transversal — TIL sur une PR
│   ├── screenshot-gist/              # Interne — Gist GitHub pour screenshots
│   ├── rails-routes/                  # Utilitaire — Génère routes-reference.txt
│   └── dev-auto-login/               # Utilitaire — Auto-login dev localhost
│
├── hooks/worktree/post-checkout       # Hook : DB isolée + copie .claude/ dans les worktrees
├── epics/                             # Vision et roadmap
├── pocs/                              # Data projet par POC (setup, specs, inventaires)
├── audits/                            # Fichiers d'audit sécurité (contrat harden-audit → harden-fix, créé à l'usage)
├── kaizen/                            # Learnings par itération
├── specs/                             # Specs techniques ponctuelles
├── docs/                              # Documentation (autolearn.md, diagrammes mermaid)
└── db/migrations/                     # Migrations SQLite (schema, backlog, autolearn)
```

Chaque POC a un numéro aligné entre skills, pocs/ et kaizen/ (ex: `2-test-optimization`).

---

*On ne construit pas un outil, on apprend à construire des workflows. L'échec fait partie du processus.*
