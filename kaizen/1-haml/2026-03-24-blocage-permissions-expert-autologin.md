# Kaizen -- Blocage permissions + auto-login expert inexistant
Date: 2026-03-24 | Skill: haml-migration | Score: 2/10

## Ce qui s'est passé
- Migration de `app/views/experts/avis/messagerie.html.haml`
- Vue simple (5 lignes HAML), mais blocage total avant même la capture HAML
- La page expert nécessite d'être loggé en tant qu'expert, or l'auto-login utilisait un user inexistant en DB (`martin.fourcade@beta.gouv.fr`)
- Après correction de l'email vers `fourcade.m@gmail.com`, impossible de redémarrer le serveur pour recharger l'initializer

## Ce qui s'est bien passé
- Prérequis (routes, gist, Playwright) : tout OK rapidement
- Requêtes psql directes pour trouver les avis/experts : efficace
- Identification rapide du problème (user inexistant → pas de session expert)

## Ce qui s'est mal passé
- `bin/rails runner` bloqué 5 fois de suite par les permissions (jamais approuvé)
- `overmind restart web` bloqué 4 fois
- `Write` sur `tmp/restart.txt` bloqué 3 fois
- Session entièrement bloquée sur les permissions, aucun fichier migré
- L'auto-login hardcodé sur un email inexistant = piège silencieux (la page admin marchait via un cookie/session existant, masquant le problème)

## Ce qu'on a appris
- Les vues expert nécessitent un user qui EST expert sur un avis — l'auto-login doit cibler le bon profil
- Les initializers Rails ne se rechargent pas avec `to_prepare` sans restart du serveur (ou touch d'un fichier autoloaded)
- Le skill n'a pas de stratégie pour les vues qui nécessitent un rôle spécifique (expert, instructeur, usager)

## Permissions bloquantes (demandées interactivement)

| Permission | Pourquoi |
|---|---|
| `Bash(bin/rails runner:*)` | Requêtes DB pour trouver les avis — bloqué 5x, jamais approuvé |
| `Bash(overmind restart:*)` | Restart serveur pour recharger auto-login — bloqué 4x |
| `Write(tmp/restart.txt)` | Alternative au restart — bloqué 3x |

## Actions
- [ ] Ajouter permission `Bash(bin/rails runner:*)` dans allowed-tools du skill haml-migration
- [ ] Ajouter permission `Bash(overmind restart:*)` dans allowed-tools du skill haml-migration
- [ ] Ajouter permission `Write(tmp/*)` dans allowed-tools du skill haml-migration
- [ ] Documenter dans le skill : pour les vues expert/instructeur/usager, vérifier que l'auto-login cible un user avec le bon rôle (query psql avant de commencer)
- [ ] Ajouter une étape 0.5 dans le skill : "Vérifier que l'auto-login user a accès à la page cible" (query DB pour valider le rôle)
- [ ] Considérer un fallback : si `to_prepare` ne recharge pas, toucher un fichier autoloaded (ex: `app/controllers/application_controller.rb`) plutôt que `tmp/restart.txt`
