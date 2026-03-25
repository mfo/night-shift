# Kaizen -- IDOR audit : faux positif non détecté
Date: 2026-03-20 | Skill: harden-audit | Score: 2/10

## Ce qui s'est passé
- Rapport IDOR sur `CommentairesController` : un instructeur pouvait passer un `dossier_id` arbitraire
- L'audit a qualifié la faille et produit un fix (scoper le lookup via `current_instructeur.dossiers`)
- Le fix est inutile pour deux raisons :
  1. Les IDs sont auto-incrémentés : un attaquant ne peut pas deviner un `dossier_id` valide sans énumération, ce qui rend l'IDOR non exploitable en pratique
  2. La chaîne d'appels protégeait déjà l'accès plus loin (l'audit n'a pas tracé assez profondément pour le voir)
- Session entière gaspillée : test + fix + PR pour rien

## Ce qu'on a appris
- Un IDOR sur des IDs auto-incrémentés n'est PAS automatiquement exploitable — il faut évaluer si l'attaquant peut obtenir/deviner les IDs
- Quand l'audit conclut "faille", il faut vérifier que la chaîne complète (controller → service → model → DB) ne protège pas déjà l'accès à un autre niveau
- L'audit superficiel (regarder un seul point) mène à des faux positifs coûteux

## Action
- [ ] harden-audit : ajouter une étape "tracer la chaîne complète d'appels" avant de conclure à une faille -> `.claude/skills/harden-audit/SKILL.md`
- [ ] harden-audit : ajouter un check "les IDs sont-ils prédictibles/énumérables ?" pour les IDOR -> `.claude/skills/harden-audit/SKILL.md`
- [ ] harden-audit : si une protection existe plus loin dans la chaîne, verdict = faux positif (pas "fix immédiat") -> `.claude/skills/harden-audit/SKILL.md`
