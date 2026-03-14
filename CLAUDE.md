# CLAUDE.md — Night Shift

Ce projet est un **méta-projet** : il contient des skills, templates et workflows pour Claude Code. Ce n'est pas une application — c'est une chaîne de production logicielle.

## Structure des Skills

Chaque skill vit dans `.claude/skills/<nom>/` avec :
- `SKILL.md` — le prompt principal (frontmatter obligatoire : `name` + `description`)
- `checklist.md` — grille de validation (optionnel)
- `template.md` — template de livrable (optionnel)
- `patterns.md` — patterns validés (optionnel)

## Règles

- **Références croisées** : quand tu déplaces ou renommes un fichier, mets à jour TOUTES les références dans les autres fichiers. Utilise `grep -r "ancien-nom"` pour les trouver.
- **Nommage générique** : pas de noms spécifiques à un outil externe dans les noms de skills (ex: `bugfix` pas `fix-sentry-bug`). Le contenu peut mentionner des outils spécifiques, pas le nom.
- **Pas de GPG sign** : utiliser `--no-gpg-sign` pour les commits.
- **Kaizen** : les retours d'expérience vont dans `kaizen/<catégorie>/iteration-N/`. Toujours extraire les learnings pour améliorer les skills.
- **DRY entre skills** : si un pattern se répète dans 2+ skills, l'extraire dans un skill réutilisable (ex: `review-3-amigos`).
- **Solution minimale d'abord** : ne pas sur-engineer. Proposer le fix le plus simple, laisser le user complexifier.
