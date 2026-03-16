# Structure du projet

```
night-shift/
├── README.md                          # Vision et approche
├── STRUCTURE.md                       # Ce fichier
├── WORKFLOW.md                        # Comment utiliser les skills
├── CLAUDE.md                          # Instructions pour Claude sur ce projet
│
├── .claude/skills/                    # Skills (le livrable principal)
│   ├── haml-migration/                # POC 1 — Migration HAML → ERB
│   ├── test-optimization/             # POC 2 — Optimisation tests lents
│   │   ├── SKILL.md                   #   Workflow agent
│   │   ├── patterns.md                #   Catalogue techniques communes
│   │   ├── patterns-system.md         #   Catalogue techniques system specs
│   │   ├── quickstart.md              #   Boot sequence worktree
│   │   └── template.md                #   Template kaizen
│   ├── bugfix/                        # POC 3 — Investigation + fix bugs
│   ├── feature-spec/                  # POC 4 — Phase 0 (spec)
│   ├── feature-plan/                  # POC 4 — Phase 1 (plan commits)
│   ├── feature-implementation/        # POC 4 — Phase 2 (code)
│   ├── feature-review/                # POC 4 — Phase 3 (review)
│   ├── kaizen/                        # Transversal — write + synth
│   └── review-3-amigos/               # Transversal — Review PM+UX+Dev
│
├── pocs/                              # Data projet par POC
│   ├── 1-haml/                        # Setup, résultats
│   ├── 2-test-optimization/           # Spec, inventaire, setup
│   ├── 3-bugs/                        # Setup
│   └── 4-features/                    # Setup, checklists, templates
│
├── kaizen/                            # Learnings par itération
│   ├── 1-haml/                        # iterations 1-4
│   ├── 2-test-optimization/           # par fichier spec
│   ├── 3-bugs/                        # iterations 1-3
│   ├── 4-features/                    # iteration 1 (6 sessions)
│   ├── templates/                     # task, weekly, improvement
│   └── weekly/                        # Rétrospectives hebdo
│
├── epics/                             # Spécifications de référence
├── specs/                             # Specs techniques ponctuelles
└── hooks/                             # Hooks git (worktree DB)
```

## Conventions

### Nommage

Chaque POC a un numéro et un nom aligné entre les 3 répertoires :

| # | Skill | POC | Kaizen |
|---|---|---|---|
| 1 | `.claude/skills/haml-migration/` | `pocs/1-haml/` | `kaizen/1-haml/` |
| 2 | `.claude/skills/test-optimization/` | `pocs/2-test-optimization/` | `kaizen/2-test-optimization/` |
| 3 | `.claude/skills/bugfix/` | `pocs/3-bugs/` | `kaizen/3-bugs/` |
| 4 | `.claude/skills/feature-*/` | `pocs/4-features/` | `kaizen/4-features/` |

### Structure d'un skill

```
.claude/skills/<nom>/
├── SKILL.md           # Prompt principal (obligatoire)
├── checklist.md       # Grille de validation (optionnel)
├── template.md        # Template de livrable (optionnel)
└── patterns.md        # Patterns validés (optionnel)
```

### Séparation des responsabilités

- **`.claude/skills/`** — le prompt, les patterns, les templates (ce que l'agent lit)
- **`pocs/`** — la data projet : inventaires, specs, résultats (ce qui change)
- **`kaizen/`** — les learnings bruts (ce que l'agent écrit après chaque session)
