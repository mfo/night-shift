---
status: traité
date_synth: 2026-08-20
status: traité
date_synth: 2026-08-20
---

# Kaizen -- Le skill test-optimization est périmé depuis la migration Oaken
Date: 2026-08-17 | Skill: test-optimization | Score: 3/10

## Ce qui s'est passé

Review de la PR #13496 (batch auto `/test-optimization` sur `rules_full_scenario_spec.rb`).
Commentaire de tchak sur `let_it_be(:administrateur) { create(:administrateur, procedures: [procedure]) }` :

> « On devrait utiliser la fixture de l'admin ici je pense. On en parlera à un moment dans la semaine pour voir comment on peut optimiser ton skill ? »

Fix appliqué dans le worktree : `administrateurs(:default_admin)` (fixture ActiveRecord globale).
**Ce fix était déjà obsolète au moment où je l'ai écrit** — la branche du worktree date d'avant la migration Oaken.

En remontant sur `origin/main` : 28 commits `oaken`, 64 commits seed depuis juillet. tchak a
remplacé tout le socle de données de test.

## Ce qui s'est bien passé

- Le fix proposé était cohérent avec ce que voyait le skill (77 fichiers utilisaient
  `administrateurs(:default_admin)` sur la branche).
- La remesure honnête a révélé que le gain annoncé dans la PR (-16.6 %) ne se reproduit pas.

## Ce qui s'est mal passé

1. **Le skill optimise contre un socle qui n'existe plus.** `patterns.md` décrit un projet où
   « test-prof est installé mais 0 usage », « `build_stubbed` = 0 usage », « la factory `:dossier`
   cascade sur `:procedure` ». Depuis Oaken, le monde entier (users, procedures, dossiers, avis,
   entreprise, messagerie) est semé **une fois par suite** — la cascade factory que le skill
   cherche à éliminer n'est plus le coût dominant.

2. **Un piège documenté est devenu faux.** SKILL.md affirme :
   « Modifiers indisponibles. `reload:` et `refind:` ne fonctionnent pas — le require est chargé
   avant Rails (`spec_helper.rb:25`). Donc `let_it_be` ne s'applique qu'aux blocs read-only. »
   Sur main, le require a été déplacé dans `rails_helper.rb`, **après Rails**, avec un commentaire
   explicite : « Required after Rails so test-prof registers its ActiveRecord let_it_be modifiers
   (reload:, refind:, freeze:). » Le skill s'auto-interdit donc `let_it_be` sur les blocs mutants
   alors que c'est désormais permis.

3. **Le skill a produit un diff que le reviewer a refusé, et j'ai corrigé vers une API supprimée.**
   Les fixtures `spec/fixtures/{administrateurs,users,instructeurs}.yml` et la ligne
   `config.global_fixtures` **n'existent plus sur main**. La forme correcte est l'accesseur Oaken
   `administrateurs.default`.

4. **Mesure non fiable sur les system specs.** Baseline HEAD mesurée à 49.4s / 42.9s, avec fix
   46.4s / 49.7s / 51.8s. Variance ±15 %. Le skill annonce des gains (-16.6 %) inférieurs à son
   propre bruit de mesure, sur 3 runs sans test de significativité.

5. **`patterns.md` est pollué.** AL-1 à AL-5 sont cinq redites du même learning trivial
   (« invoquer via Agent, pas Skill ») — 5 entrées sur 5 dans la section auto-discovered.

## Ce qu'on a appris

- **Un skill qui encode l'état d'un codebase pourrit silencieusement.** Rien n'a échoué : les
  tests étaient verts, la PR est passée, 19/19 checks OK. Seul un humain qui connaît la
  trajectoire du projet a vu le problème. Le skill n'a aucun moyen de détecter que son modèle
  du monde est périmé.
- **Corollaire : le skill doit lire la vérité du repo au lieu de la mémoriser.** `AGENTS.md`
  §Testing Philosophy sur main dit déjà tout ce qu'il faut (« Prefer Oaken seeds over factories »,
  seed-safety, `empty_seeds`). Le skill aurait dû le lire à l'étape 0 plutôt que porter sa propre
  copie divergente.
- **Un gain inférieur au bruit de mesure n'est pas un gain.** Sur les system specs (dominés par
  Playwright), le coût de setup DB est marginal — il faut soit exclure ces fichiers du reporting
  de gain, soit exiger un écart > écart-type observé.

## Permissions bloquantes (demandées interactivement)

Aucune. Toutes les commandes (`gh api`, `git show origin/main:*`, `bundle exec rspec`) sont passées.

## Actions

- [ ] Ajouter technique T13 (Oaken seeds) en tête de catalogue -> `patterns.md`
- [ ] Ajouter le catalogue des accesseurs semés + seeds `cases/` -> `patterns.md`
- [ ] Supprimer le piège « modifiers indisponibles » (faux depuis le déplacement du require) -> `SKILL.md`
- [ ] Ajouter les règles seed-safety (`empty_seeds`, jamais de compte global) -> `SKILL.md`
- [ ] Étape 0 : lire `AGENTS.md` §Testing Philosophy avant de profiler, au lieu de mémoriser l'état du repo -> `SKILL.md`
- [ ] Étape 2 : ajouter le signal `create(:` vs accesseur semé disponible -> `SKILL.md`
- [ ] Seuil de gain : exiger un écart > variance mesurée ; ne pas reporter de gain sur system specs -> `SKILL.md`
- [ ] Purger AL-1..AL-5 (5 doublons) en une seule entrée -> `patterns.md`
- [ ] Corriger le fix de la PR #13496 : `administrateurs.default`, pas `administrateurs(:default_admin)` -> PR #13496
