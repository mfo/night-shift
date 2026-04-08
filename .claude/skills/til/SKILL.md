---
name: til
description: Poster un commentaire TIL (Today I Learned) sur une PR pour partager un apprentissage / clarification avec l'equipe
user_invocable: true
---

# TIL (Today I Learned)

Partager un concept technique sur une PR. Sharing is caring.

## Etape 1 : Identifier le sujet

- Si l'utilisateur precise un sujet, utilise-le
- Sinon, analyse la PR courante et identifie le concept le plus interessant a partager

## Etape 2 : Rediger le TIL

### Format

```markdown
## TIL : [Titre court]

[Explication claire en 2-3 phrases]

[Schema ASCII si ca aide — privilegier les schemas pour les concepts visuels/temporels]

[Exemple concret tire de la PR]
```

### Regles

- Direct, clair, pas condescendant
- Lisible en 2 minutes
- Schemas ASCII quand ca aide (pas de mermaid)
- Toujours rattacher au contexte concret de la PR

## Etape 3 : Poster

```bash
gh pr comment <PR_NUMBER> --repo demarche-numerique/demarches-simplifiees.fr --body "..."
```
