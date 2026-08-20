---
status: traité
date_synth: 2026-06-16
---
# Kaizen — Batch haml-migration: InputComponent 98 turns sans commit
Date: 2026-06-16 | Skill: haml-migration | Score: 2/10

## Ce qui s'est passé
- Batch haml-migration sur `Dsfr::InputComponent` (composant de base, 0 utilisation directe dans les views)
- 98 turns, 18 min, 0 commits, `no_diff`
- Le modèle a tâtonné : créé un ViewComponent preview, tenté des screenshots, échoué sur le sélecteur CSS `.fr-input-group`

## Ce qui s'est bien passé
- Le modèle a correctement identifié l'absence d'utilisation directe et a tenté de créer un preview (approche valide)
- Le gist screenshot a été créé avec succès

## Ce qui s'est mal passé
- 4 permissions playwright refusées (`browser_evaluate`, `browser_run_code_unsafe`, `browser_console_messages`) → le modèle a bouclé sans pouvoir prendre de screenshot
- Tentative de lire un fichier de 279k tokens (rejeté par la limite)
- Rubocop a trouvé des offenses dans le preview créé
- Le modèle n'a pas abandonné tôt malgré l'impasse → 98 turns gaspillés

## Ce qu'on a appris
- Les composants sans utilisation directe (composants de base/abstraits) sont des mauvais candidats pour la migration auto — pas de page où valider visuellement
- Le skill devrait détecter tôt "0 utilisations" et soit utiliser les previews existants, soit abandonner proprement
- Les permissions playwright manquantes dans allowed-tools causent des boucles silencieuses

## Permissions bloquantes (demandées interactivement)

| Permission | Pourquoi |
|---|---|
| `mcp__playwright__browser_evaluate` | Évaluer du JS dans la page pour vérifier le rendu |
| `mcp__playwright__browser_run_code_unsafe` | Prendre des screenshots avec clip/padding |
| `mcp__playwright__browser_console_messages` | Vérifier les erreurs console |

## Actions
- [ ] Ajouter les 3 permissions playwright dans allowed-tools du skill haml-migration
- [ ] Ajouter un pattern dans patterns.md : "Si 0 utilisations directes, utiliser le ViewComponent preview existant ou en créer un. Si le preview ne fonctionne pas après 2 tentatives, abandonner avec un message explicite."
- [ ] Envisager un max-turns plus bas pour les skills mécaniques sur ds4 local (98 turns = gaspillage)
