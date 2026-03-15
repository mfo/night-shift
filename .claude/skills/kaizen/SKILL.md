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
Créer `kaizen/<catégorie>/YYYY-MM-DD-<titre>.md` avec le template (`kaizen/templates/task.md`).
Pré-remplir "Ce qui s'est passé" à partir de git log.

### 4. Poser UNE question
"Qu'est-ce que tu as appris ?"

### 5. Boucle fermée
Si une action cible un fichier de skill (SKILL.md, checklist.md, patterns.md) :
- Lire le fichier
- Proposer un diff concret
- Appliquer seulement si le dev valide
