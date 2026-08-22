---
name: create-pr
description: "Create a GitHub pull request. Use when user says 'cree la PR', 'push', or work is ready for review."
user_invocable: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(git status)
  - Bash(git push:*)
  - Bash(gh pr create:*)
  - Bash(gh pr edit:*)
  - Skill(pr-description)
---

# Creation de Pull Request

## Etape 1 : La description

Dans l'ordre : si `pr-description.md` existe, le lire ; sinon si le skill `pr-description`
est disponible, l'utiliser ; sinon rediger directement.

Dans les trois cas, le budget ci-dessous prime sur tout le reste.

### Titre

`Nature: ETQ persona, description courte en francais`

Natures : `Correctif` (bug) | `Amelioration` (feature) | `Tech` (refacto, CI, perf, dette) | `Secu`.
Personas : `usager` | `instructeur` | `admin` | `expert`. Pas de persona pour `Tech` et `Secu`.

### Budget

Titre + `# Probleme` (2-4 lignes) + `# Solution` (2-4 lignes). C'est tout.

Le reviewer doit comprendre le "pourquoi" sans lire le code — rien de plus. Dans le doute,
ne pas ajouter : ce qui manque se demande en commentaire, ce qui est en trop ne se lit pas.

### Sections en plus : uniquement dans ces cas

| Ajout | Uniquement si |
|---|---|
| Screenshots avant/apres | le rendu visuel change |
| Tableau de metriques | PR de perf, chiffres avant/apres a l'appui |
| Requete SQL | le reviewer doit verifier un etat prod avant de merger |
| Diagramme | flux non lineaire que le texte ne rend pas |
| Section "Apres merge" | une action manuelle est requise |
| `depends_on:` / `follows:` | la PR depend d'une autre. Non mergee : prefixer le titre `WIP - depends_on#XXXX –` |

### Jamais

- La demonstration qu'un changement est sur : ca se repond en commentaire si on la demande
- La liste des tests qui passent : la CI le dit
- Une section "pour plus tard" ou les travaux connexes : c'est une issue
- Le recit de l'investigation, la liste des fichiers modifies : le diff est la pour ca

## Etape 2 : Creer la PR

1. Pousser la branche si pas deja fait (`git push mfo <branch>`)
2. Proposer titre + description au user pour validation
3. Creer la PR avec `gh pr create`

```bash
gh pr create --repo demarche-numerique/demarche.numerique.gouv.fr \
  --head mfo:<branch> \
  --title "le titre" \
  --body "$(cat <<'EOF'
# Probleme

...

# Solution

...

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```
