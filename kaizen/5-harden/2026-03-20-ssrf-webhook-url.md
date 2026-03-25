# Kaizen -- SSRF sur web_hook_url
Date: 2026-03-20 | Skill: harden-fix | Score: ?/10

## Ce qui s'est passé
- Audit SSRF sur `web_hook_url` dans `Procedure` / `WebHookJob`
- Approche TDD en 2 commits : tests rouges prouvant la faille, puis correctif
- Création d'un validateur `NoPrivateIPURLValidator` (IPs privées littérales) + protection DNS runtime dans le job
- Discussion sur le DNS rebinding et l'évaluation du risque réel (blind SSRF POST, body non contrôlé)
- PR créée avec description structurée Problème/Solution

## Ce qui s'est bien passé
- Le split en 2 commits (red/green) a bien fonctionné avec git stash pour isoler le fix
- La discussion risque réel a permis de nuancer la PR (infra cloud vs privée)
- Le validateur réutilise sa méthode `private_ip?` dans le job — pas de duplication

## Ce qui s'est mal passé
- Le nouveau fichier validateur (untracked) ne pouvait pas être stashé avec `git stash push` — fallback sur `mv /tmp`
- Nommage de classe : `NoPrivateIpUrlValidator` vs `NoPrivateIPURLValidator` à cause des acronymes dans inflections.rb — erreur au premier run

## Ce qu'on a appris
-

## Permissions bloquantes (demandées interactivement)

| Permission | Pourquoi |
|---|---|
| `Bash(git push)` | refusé une première fois car l'utilisateur voulait relire avant |

## Actions
- [ ] Le skill harden-fix pourrait documenter le pattern stash+mv pour les fichiers untracked lors du split red/green
- [ ] Vérifier les inflections.rb avant de nommer un validateur (acronymes IP, URL, API, etc.)
