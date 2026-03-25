# Kaizen -- harden-audit IDOR procedures detail
Date: 2026-03-20 | Skill: harden-audit | Score: 7/10

## Ce qui s'est passé
- Audit d'un rapport IDOR sur `ProceduresController#detail` (Procedure.find non scopé)
- Tracé la chaîne complète : route → controller parent (auth) → before_action (manquant) → action → vue
- Initialement qualifié à DREAD 8/15 (sprint courant)
- Le dev a challengé : "l'admin peut déjà voir les emails des autres admins"
- Vérifié que `all` et `administrateurs` exposent déjà les emails pour publiees_ou_closes
- Réduit à DREAD 6/15, reclassé en hardening/backlog

## Ce qui s'est bien passé
- Chaîne d'appels bien tracée, faille confirmée rapidement
- Fichier d'audit structuré et complet du premier coup
- Réaction rapide au feedback : vérification du contexte fonctionnel (ce qui est déjà exposé by design)

## Ce qui s'est mal passé
- **Pas vérifié le contexte fonctionnel avant de scorer** : j'aurais dû regarder ce que `all` et `administrateurs` exposent AVANT de qualifier l'impact. Le dev a dû me corriger.
- Le DREAD initial surévaluait le Damage (2 au lieu de 1) parce que je n'avais pas regardé le baseline d'exposition

## Ce qu'on a appris
- ...

## Permissions bloquantes (demandées interactivement)

| Permission | Pourquoi |
|---|---|
| Aucune | Session lecture seule (audit) |

## Actions
- [ ] Ajouter au skill harden-audit : "Avant de scorer DREAD, vérifier ce qui est DÉJÀ exposé by design sur la même surface (même controller, même page). Le delta réel = nouvelle exposition - exposition existante." -> `.claude/skills/harden-audit/checklist.md`
- [ ] Ajouter un pattern "IDOR atténué par exposition by-design" dans patterns.md -> `.claude/skills/harden-audit/patterns.md`
