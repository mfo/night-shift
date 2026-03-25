# Kaizen -- harden-fix : tracer chaque appel de la chaîne
Date: 2026-03-20 | Skill: harden-fix | Score: 3/10

## Ce qui s'est passé
- Le skill harden-fix a pris le fichier d'audit tel quel et a foncé sur le fix
- Il n'a pas vérifié indépendamment si la faille était réelle en traçant la chaîne d'appels complète
- Résultat : un fix appliqué sur un point d'entrée qui était déjà protégé en aval

## Ce qu'on a appris
- Le skill harden-fix ne doit pas faire confiance aveuglément au fichier d'audit
- Avant de coder le fix, il faut tracer pas-à-pas chaque appel depuis le point d'entrée (route → controller → before_action → méthode → service → model → query) pour confirmer que la faille est réelle
- Un "Dossier.find(params[:dossier_id])" qui semble vulnérable peut être protégé par un scope ou un check plus loin dans le flow

## Action
- [ ] harden-fix : ajouter une étape 2bis "Tracer la chaîne complète" entre l'analyse du code et le plan de commits -> `.claude/skills/harden-fix/SKILL.md`
- [ ] harden-fix : cette étape doit lister chaque appel de la chaîne avec le fichier:ligne et conclure "protégé à [niveau]" ou "non protégé" -> `.claude/skills/harden-fix/SKILL.md`
- [ ] harden-fix : si la chaîne est déjà protégée, challenger l'audit et demander validation avant de coder -> `.claude/skills/harden-fix/SKILL.md`
