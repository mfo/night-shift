---
triggers: [flipper, feature-flag, toggle, boolean, activation]
---
# Flipper vs Colonne Boolean

**Piege :** Utiliser Flipper par defaut pour tout feature flag, meme quand le flag est lie a l'objet lui-meme (procedure, dossier) et pas a un acteur/environnement.

**Solution :** Evaluer le porteur du flag :
- **Flag lie a un acteur** (user, equipe) ou a un environnement (staging/prod) → Flipper
- **Flag lie a l'objet** (procedure, formulaire) → Colonne boolean, plus simple et queryable

**Signe d'alerte :** Si la spec mentionne `Flipper.enabled?(:feature, procedure)` — c'est probablement une colonne.

**Ref :** kaizen 2026-03-30 (referentiel-tiptap-url)
