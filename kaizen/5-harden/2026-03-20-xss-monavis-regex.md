# Kaizen -- XSS MonAvis regex bypass
Date: 2026-03-20 | Skill: harden-audit + harden-fix | Score: 9/10

## Ce qui s'est passé
- Faille XSS identifiée sur le validateur d'embed MonAvis : la regex utilisait une alternation mal groupée (`monavis.numerique.gouv.fr|button.numerique.gouv.fr`) qui permettait d'injecter des domaines arbitraires finissant par `button.numerique.gouv.fr`
- Source : review Claude avec expert (session à retrouver)
- Pipeline `/harden-audit` → `/harden-fix` utilisé bout en bout, fluide

## Ce qu'on a appris
- Les non-capturing groups `(?:...)` dans les regex permettent de grouper les alternations proprement sans polluer les captures — ici c'est ce qui a permis de restreindre la regex aux seuls domaines autorisés
- Le pipeline audit → fix fonctionne bien : l'audit structure le problème, le fix consomme l'audit en TDD (test rouge prouvant le bypass, puis fix + inversion)

## Action
- [ ] Retrouver la session review Claude + expert qui a produit le rapport initial
- [ ] Ajouter au skill kaizen : poser les questions UNE PAR UNE (pas en bloc) pour éviter les pavés
