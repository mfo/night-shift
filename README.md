# Night Shift — Workflows de développement avec IA

**Statut :** Démonstrateur — Exploration et apprentissage en cours (N=1)

---

## L'idée

Développer sur des projets complexes = tâches répétitives, règles à respecter, charge mentale constante. Peut-on déléguer certaines de ces tâches à un agent IA ?

Pas tout automatiser d'un coup. Juste : choisir UNE tâche, créer un prompt, observer ce qui marche, améliorer, répéter.

## Approche

**Petits pas itératifs, adapté à VOTRE projet.** Pas de prompt géant de 2000 lignes, pas de solution universelle.

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

Détails dans `pocs/`.

## Limites connues

- **N=1** : 1 créateur, 1 projet — aucun résultat n'est reproductible tant qu'un 2e utilisateur n'a pas testé
- **Périmètre = apprentissage** : l'objectif est la capacité à créer des skills, pas la productivité immédiate
- **Vendor lock-in opérationnel** : les skills sont liés à Claude Code (le code produit reste portable)

## Documentation

| Fichier | Contenu |
|---|---|
| `STRUCTURE.md` | Architecture du projet |
| `WORKFLOW.md` | Guide pratique (lancer un POC, documenter) |
| `QUICKSTART.md` | Démarrage rapide |
| `pocs/` | POCs et résultats |
| `kaizen/` | Learnings par itération |
| `.claude/skills/` | Skills (le livrable principal) |

---

*On ne construit pas un outil, on apprend à construire des workflows. L'échec fait partie du processus.*
