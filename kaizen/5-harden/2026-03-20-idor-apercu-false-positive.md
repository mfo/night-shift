# Kaizen -- IDOR apercu : faux positif bien analysé
Date: 2026-03-20 | Skill: harden-audit | Score: 7/10

## Ce qui s'est passé
- Investigation d'un rapport YWH signalant un IDOR sur `GET /admin/procedures/:id/apercu`
- `procedure_without_control` utilise `Procedure.find(params[:id])` sans scoper à `current_administrateur.procedures`
- Première analyse concluait à un IDOR réel mais à impact limité
- Le dev a pointé qu'il fallait regarder plus bas dans la chaîne : `dossier_for_preview(current_user)` scope le dossier au user courant
- Conclusion finale : **pas un IDOR exploitable** — seule la structure du formulaire est exposée, et elle est déjà publique pour les procédures publiées

## Ce qui s'est bien passé
- Bonne investigation initiale : identification du `before_action`, du `retrieve_procedure` manquant, de la chaîne `procedure_without_control`
- Correction rapide après feedback du dev

## Ce qui s'est mal passé
- Conclusion initiale trop hâtive : a déclaré "c'est un IDOR" sans avoir suivi la chaîne complète (`dossier_for_preview` → scopé au `current_user`)
- Le skill harden-audit devrait insister sur le fait de tracer la chaîne complète avant de conclure, pas juste le contrôleur

## Ce qu'on a appris
- Toujours suivre la chaîne complète : contrôleur → modèle → données effectivement exposées avant de qualifier une faille
- Un `find` non scopé n'est pas automatiquement un IDOR si les données retournées sont publiques ou scopées plus bas
- Pour les procédures publiées, la structure du formulaire est publique — pas de fuite de données sensibles
- Distinguer "accès à une ressource" vs "accès à des données sensibles via cette ressource"

## Permissions bloquantes (demandées interactivement)

| Permission | Pourquoi |
|---|---|
| Aucune | Session de lecture/investigation uniquement |

## Actions
- [ ] Ajouter dans le skill harden-audit une étape "tracer la chaîne complète jusqu'aux données exposées" avant de qualifier -> `.claude/skills/harden-audit/`
- [ ] Documenter le pattern "find non scopé ≠ IDOR si données publiques ou scopées en aval" -> `.claude/skills/harden-audit/`
