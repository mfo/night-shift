---
status: traité
date_synth: 2026-06-16
---
# Kaizen — HAML data attributes : underscore → tiret silencieux
Date: 2026-06-16 | Skill: haml-migration | Score: 3/10

## Ce qui s'est passé
- Migration du composant `referentiels/new_form_component` de HAML vers ERB (commit 26d7ab05)
- Le HAML contenait `data: { 'hide-target_target' => 'toHide' }` dans un hash Ruby
- HAML convertit automatiquement les underscores en tirets pour les data attributes dans le rendu HTML : `data-hide-target-target="toHide"`
- Le skill a converti littéralement en ERB : `data-hide-target_target="toHide"` — gardant l'underscore
- Le HTML rendu est différent : le target Stimulus `hide-target-target` ne fonctionne plus
- Nécessité d'une PR corrective (#13302) pour changer l'underscore en tiret

## Ce qui s'est bien passé
- La migration a été détectée comme problématique et corrigée rapidement

## Ce qui s'est mal passé
- Le skill n'a pas compris la convention HAML de conversion automatique underscore → tiret dans les data attributes
- La validation visuelle n'a pas détecté la régression (le composant nécessite une interaction JS pour révéler le bug)

## Ce qu'on a appris
- HAML `data: { 'foo_bar' => 'x' }` → HTML `data-foo-bar="x"` (conversion automatique)
- En ERB, le data attribute doit être écrit avec des tirets directement : `data-foo-bar="x"`
- Même pattern avec les data hashes Rails : `data: { hide_target_target: 'toHide' }` → `data-hide-target-target`
- Ce piège est invisible aux tests de rendu statique — il faut tester l'interaction JS (Stimulus)

## Actions
- [ ] Ajouter un pattern dans patterns.md : conversion data attributes HAML underscore → tiret en ERB
