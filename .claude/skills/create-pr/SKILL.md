---
name: create-pr
description: "Create a GitHub pull request. Use when user says 'cree la PR', 'push', or work is ready for review."
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

## Etape 1 : Generer la description

Si `pr-description.md` n'existe pas deja, utiliser le skill `pr-description` pour le generer.

Si `pr-description.md` existe, le lire et proposer au user pour validation.

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
EOF
)"
```
