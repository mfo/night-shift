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

## Utiliser un skill

Les skills sont des slash commands. Lancer Claude Code dans le projet cible :

```bash
/haml-migration app/views/path/to/file.html.haml
/test-optimization spec/models/dossier_spec.rb
/bugfix <description ou lien Sentry>
/feature-spec → /feature-plan → /feature-implementation → /feature-review
```

Après une session : `/kaizen write`. Pour améliorer les skills : `/kaizen synth`.

Review transversale : `/review-3-amigos <spec, plan, ou PR diff>`.

## Structure

```
night-shift/
├── .claude/skills/                    # Skills (le livrable principal)
│   ├── haml-migration/                # POC 1
│   ├── test-optimization/             # POC 2
│   ├── bugfix/                        # POC 3
│   ├── feature-spec/                  # POC 4 — Phase 0
│   ├── feature-plan/                  # POC 4 — Phase 1
│   ├── feature-implementation/        # POC 4 — Phase 2
│   ├── feature-review/                # POC 4 — Phase 3
│   ├── kaizen/                        # Transversal — write + synth
│   └── review-3-amigos/              # Transversal — Review PM+UX+Dev
│
├── pocs/                              # Data projet par POC (setup, specs, inventaires)
├── kaizen/                            # Learnings par itération
├── specs/                             # Specs techniques ponctuelles
└── hooks/                             # Hooks git (worktree DB)
```

Chaque POC a un numéro aligné entre skills, pocs/ et kaizen/ (ex: `2-test-optimization`).

## Limites connues

- **N=1** : 1 créateur, 1 projet — aucun résultat n'est reproductible tant qu'un 2e utilisateur n'a pas testé
- **Périmètre = apprentissage** : l'objectif est la capacité à créer des skills, pas la productivité immédiate
- **Vendor lock-in opérationnel** : les skills sont liés à Claude Code (le code produit reste portable)

---

*On ne construit pas un outil, on apprend à construire des workflows. L'échec fait partie du processus.*
