---
name: kaizen
description: Documenter les learnings d'une session — git log comme gemba, Post-it comme format
---

# Kaizen — Post-it post-session

## Quand l'utiliser
Après une session de travail significative. Si tu n'as rien à dire, ne dis rien.

## Workflow

### 1. Observer le gemba
```bash
git log --oneline --since="today"
git diff --stat HEAD~N
```

### 2. Suggérer la catégorie
Basé sur les fichiers modifiés, proposer où ranger le kaizen :
- `kaizen/1-haml/` si .haml/.erb
- `kaizen/3-bugs/` si bugfix
- `kaizen/4-features/` si feature
- Le dev confirme ou corrige (2 secondes).

### 3. Pré-remplir le Post-it
⚠️ **Toujours créer dans `~/dev/night-shift/`** — jamais dans le repo de travail courant.

Créer `~/dev/night-shift/kaizen/<catégorie>/YYYY-MM-DD-<titre>.md` avec le template (`kaizen/templates/task.md`).
Pré-remplir "Ce qui s'est passé" à partir de git log.

### 4. Poser UNE question
"Qu'est-ce que tu as appris ?"

### 5. Lister les permissions bloquantes
Parcourir la session et lister les permissions qui ont été demandées interactivement. Les ajouter comme action dans le Post-it :
- Ex: `- [ ] Ajouter permission Bash(bun lint:herb:*) dans allowed-tools du skill`

### 6. Déposer, ne pas appliquer
Le kaizen est un **livrable passif** : déposer le fichier dans `~/dev/night-shift/kaizen/` et c'est tout.
**NE JAMAIS** proposer d'appliquer les corrections au skill depuis la session de travail — c'est le rôle de night-shift qui consomme les kaizens.
