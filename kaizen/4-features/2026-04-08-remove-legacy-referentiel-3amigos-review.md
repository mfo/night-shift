---
status: traité
date_synth: 2026-04-08
---

# Kaizen -- Review 3 Amigos spec suppression legacy referentiel
Date: 2026-04-08 | Skill: review-3-amigos, feature-spec | Score: ?/10

## Ce qui s'est passe
- Session de review 3 Amigos (PM Staff + UX Staff + Dev Staff) sur la spec v2 de suppression du code legacy referentiel (branches `use_tiptap?`)
- 3 agents lances en parallele, findings consolides et presentes point par point
- Resultat : 2 bloquants, 5 importants, 5 nice-to-have
- User a valide 4 findings, rejete 8 (dont beaucoup "detail d'implementation a voir au codage")

## Ce qui s'est bien passe
- Les profils Staff ont detecte un fichier oublie critique (`_url_validation_feedback.html.erb`) que la spec ne listait pas — aurait casse silencieusement les erreurs de validation URL en prod
- Le finding sur la resolution d'URL tiptap pour l'affichage historique a mene a une meilleure decision (resoudre avec test_data_tiptap au lieu d'afficher du JSON brut)
- Le workflow point par point permet au user de trier rapidement (valide/rejete en 1 mot)
- Upgrade Senior -> Staff a apporte plus de profondeur (partial oublie, i18n, coherence 3 couches)

## Ce qui s'est mal passe
- 8/12 findings rejetes — trop de "details d'implementation" remontes comme findings importants
- Les agents Dev/PM suggerent des checks pre-deploy et des estimations que le user considere hors scope de la spec
- Le finding "70% du fichier a reecrire" etait exagere (en realite ~50% des lignes, et c'est du detail d'impl)
- Certains findings nice-to-have (GraphQL, nommage tiptap) etaient des non-sujets evidents

## Ce qu'on a appris
- Ne jamais parler d'estimation de temps — ca fait perdre du temps au user. Ni dans les specs, ni dans les reviews, ni dans les findings.

## Permissions bloquantes (demandees interactivement)

| Permission | Pourquoi |
|---|---|
| Aucune | Session de review pure, pas d'execution |

## Actions
- [ ] Affiner le prompt des teammates pour distinguer "finding spec" vs "detail d'implementation a traiter au codage" -> `.claude/skills/review-3-amigos/skill.md`
- [ ] Ajouter une instruction aux teammates : ne pas remonter d'estimations de temps ni de checks pre-deploy operationnels -> `.claude/skills/review-3-amigos/skill.md`
- [ ] Considerer un filtre "est-ce que ca change la spec ou est-ce que ca change l'implementation ?" avant de remonter un finding -> `.claude/skills/review-3-amigos/skill.md`
