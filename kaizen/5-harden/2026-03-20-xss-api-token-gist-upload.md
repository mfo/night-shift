# Kaizen -- Upload de screenshots PNG sur un gist GitHub via CLI
Date: 2026-03-20 | Skill: harden-fix | Score: ?/10

## Ce qui s'est passé
- Fix XSS sur `api_token_autorisation_controller.ts` (insertAdjacentHTML → DOM APIs)
- Pour la PR, il fallait uploader 3 screenshots (setup, faille, fix) sur GitHub
- `gh gist create` ne supporte pas les fichiers binaires (PNG) → échec direct
- Tentative d'upload via `gh api --method PATCH` avec base64 → les fichiers sont stockés en texte base64, pas en binaire → inutilisable comme image
- Tentative d'upload via l'API uploads de GitHub (`uploads.github.com`) → endpoint non documenté, "Bad Size" errors
- Solution trouvée en lisant le skill haml-migration : cloner le gist en HTTPS, copier les PNG dedans, commit + push → les fichiers binaires sont bien servis en raw
- La technique du gist cloné fonctionne parfaitement pour les fichiers binaires

## Ce qu'on a appris
- Le modèle de PR sécurité (Summary + Root cause + Fix + screenshots Avant/Après via gist) est validé et accepté par l'équipe — à réutiliser tel quel dans harden-fix

## Modèle de PR sécurité (validé par l'équipe)

```markdown
## Summary

[Description de la faille : quel contrôleur/composant, quel vecteur d'attaque, quel impact]

### Root cause

[Code vulnérable avec extrait, explication de pourquoi c'est exploitable]

### Fix

[Description de la correction, pourquoi elle résout le problème]

## Avant / Après

### 1. Setup — [contexte de la faille]
![setup](https://gist.githubusercontent.com/<user>/<gist-id>/raw/setup.png)

### 2. Avant (faille) — [ce qui se passe avant le fix]
![faille](https://gist.githubusercontent.com/<user>/<gist-id>/raw/faille.png)

### 3. Après (fix) — [ce qui se passe après le fix]
![fix](https://gist.githubusercontent.com/<user>/<gist-id>/raw/fix.png)
```

## Action
- [ ] Documenter la technique "gist cloné pour binaires" dans un skill dédié ou dans harden-fix -> `.claude/skills/harden-fix/SKILL.md`
- [ ] Ajouter les permissions `Bash(gh gist create:*)`, `Bash(gh auth setup-git:*)`, `Bash(git clone:*)`, `Bash(git -C /tmp/:*)`, `Bash(cp:*)` dans le skill harden-fix si elles manquent
