# Kaizen -- Le skill kaizen crée des frictions évitables
Date: 2026-03-15 | Skill: kaizen | Score: 4/10

## Ce qui s'est passé
- Le LLM a créé le fichier kaizen dans le repo local (`demarches-simplifiees.fr-poc-haml/kaizen/`) au lieu de `night-shift/kaizen/`
- L'utilisateur a dû demander de déplacer le fichier manuellement
- Les permissions du skill haml-migration n'ont pas été listées proactivement — l'utilisateur a dû les demander explicitement

## Ce qu'on a appris
- Le skill kaizen ne précise pas **où** créer les fichiers → le LLM crée dans le repo courant par défaut
- Le skill kaizen ne demande pas de lister les permissions bloquantes → le LLM ne le fait pas spontanément
- Chaque friction = 1 aller-retour humain évitable
- Le LLM ne doit pas proposer d'appliquer les corrections au skill lui-même — c'est le rôle de night-shift qui consomme les kaizens

## Action
- [x] Ajouter dans `kaizen/SKILL.md` le chemin absolu de destination : `~/dev/night-shift/kaizen/` → SKILL.md étape 3
- [x] Ajouter dans `kaizen/SKILL.md` une étape "Lister les permissions demandées pendant la session et les ajouter comme action dans le post-it" → SKILL.md étape 5
- [x] Ne jamais proposer d'appliquer les corrections au skill depuis la session de travail — déposer le kaizen dans night-shift et laisser night-shift s'en occuper → SKILL.md étape 6
