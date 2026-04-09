---
name: create-pr
description: Creer une PR sur GitHub en respectant le format d'equipe (nature, persona, probleme/solution)
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
---

# Creation de Pull Request

Tu crees une PR GitHub en respectant le format d'equipe.

## Etape 1 : Analyser les changements

1. Identifier la branche courante et la branche cible (main)
2. Lire tous les commits entre main et HEAD (`git log main..HEAD`, `git diff main...HEAD`)
3. Comprendre la nature et le scope des changements

## Etape 2 : Determiner la nature et le titre

### Format du titre

```
Nature: ETQ persona, description courte en francais
```

### Natures possibles

| Nature | Quand | Exemple de titre |
|--------|-------|-----------------|
| `Correctif` | Bug fix, correction d'erreur | `Correctif: ETQ usager, corriger le bouton retry d'upload` |
| `Amelioration` | Nouvelle feature, enhancement | `Amelioration: ETQ admin, pouvoir filtrer par date` |
| `Tech` | Refactoring, CI, tooling, perf, dette technique | `Tech: migrer les templates HAML vers ERB` |
| `Secu` | Securite, hardening | `Secu: sanitizer les liens stockes en base` |

### Personas (ETQ = En Tant Que)

- `usager` — utilisateur qui remplit un dossier
- `instructeur` — agent qui traite les dossiers
- `admin` — administrateur qui cree les procedures
- `expert` — invite a donner un avis sur un dossier
- Pour `Tech` et `Secu` : pas de persona, juste la description
- Le titre peut etre expressif et humain, ex: `ETQ tech, je veux un code plus simple : supprimer la surcharge transitoire`

## Etape 3 : Rediger la description

### Header de chainage (si applicable)

Quand la PR fait partie d'une chaine ou depend d'une autre PR :

```markdown
depends_on: <url PR parente>
```
ou
```markdown
follows: <url PR precedente>
```

Si la PR depend d'une PR non encore mergee, prefixer le titre avec `WIP - depends_on#XXXX –`.

### Intro narrative (optionnel)

Si il y a un contexte a donner (extraction d'une PR, discussion d'equipe, decision prise en amont), l'ajouter en texte libre avant `# Probleme`.

### Structure obligatoire

```markdown
# Probleme

[Explication du probleme, du contexte, pourquoi on fait cette PR]

# Solution

[Explication de la solution, approche choisie, compromis]
```

**Concision** : si le diff est trivial (quelques lignes), `# Solution` peut etre omis — le diff parle de lui-meme.

### Regles par nature

**Correctif :**
- Probleme : decrire le bug observe, impact utilisateur, lien Sentry si dispo
- Solution : root cause + fix. Si possible, screenshots avant/apres

**Amelioration :**
- Probleme : besoin utilisateur, contexte metier
- Solution : ce qui a ete implemente, choix UX/tech. Screenshots si visuel

**Tech :**
- Probleme : dette technique, perf, maintenabilite
- Solution : approche choisie et pourquoi. Metriques si perf (avant/apres)

**Secu :**
- Probleme : chronologie, inventaire des surfaces concernees, impact
- Solution : fix, defense en profondeur, requetes de verification prod si pertinent

### Enrichissements optionnels (selon pertinence)

- **Tableaux** : inventaire de champs, metriques avant/apres, chronologie
- **Screenshots** : pour tout changement visuel (avant/apres)
- **Requetes SQL** : pour verifier l'etat de la data en prod
- **Diagrammes de flux** : pour les workflows complexes (ASCII ou mermaid)
- **Section "Pourquoi cette approche ?"** : quand plusieurs alternatives existent, expliquer les compromis
- **Section "Apres merge"** : si des actions manuelles sont requises post-merge


## Etape 4 : Creer la PR

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

## Contraintes

- Titre en francais
- Description concise mais complete — le reviewer doit comprendre le "pourquoi" sans lire le code
- Ne pas sur-documenter : pas de liste exhaustive de fichiers modifies, le diff est la pour ca
- Adapter le niveau de detail a la complexite : un one-liner n'a pas besoin de 3 paragraphes
