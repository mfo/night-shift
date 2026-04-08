# Kaizen -- Divergences plan/implementation referentiel-tiptap-url
Date: 2026-03-30 | Skill: feature-spec, feature-plan | Score: 6/10

## Ce qui s'est passe
Implementation de la feature "URL dynamique des referentiels via TipTap" sur demarches-simplifiees.fr. Le plan prevu 18 commits atomiques. A mi-parcours (~10 commits), 6 divergences significatives identifiees entre le plan et l'implementation reelle.

## Ce qui s'est bien passe
- Le decoupage DB -> model -> service -> controller -> composant etait correct
- Les tests restent verts a chaque commit
- La review 3 Amigos a detecte un probleme UX bloquant (test_data decorrele de l'editeur URL) avant qu'il soit trop tard
- Le format tableau DSFR pour les test_data est nettement superieur aux inputs simples prevus

## Ce qui s'est mal passe
- **Flipper sur-specifie** : la spec imposait Flipper par procedure alors qu'une simple colonne boolean suffisait. 3 commits du plan (1.2, 1.3, 2.1) ont ete elimines/simplifies
- **Incompatibilite autosubmit/TipTap non anticipee** : ProseMirror est detruit par turbo_stream replace du formulaire entier. A necessite un pivot architectural (route dediee validate_url) non prevu
- **Custom setter JSONB oublie** : les hidden fields TipTap envoient du JSON en string, pas un Hash. Pattern pourtant existant dans le codebase (tiptap_template=)
- **Placement UX des test_data** : le plan mettait les test_data dans la section mode/hint, loin de l'editeur URL. Le lien cognitif tag<->test_data etait invisible
- **Decoupage trop fin** : commits 5.1/5.2/5.3 fusionnes en 1 car interdependants
- **Wording tags generique** : la cle i18n `properties` etait partagee et inadaptee au contexte URL

## Ce qu'on a appris
- **"Une spec floue donne une connerie precise"** : les 6 divergences viennent toutes de zones ou la spec etait vague ou faisait des choix d'implementation prematures (Flipper, placement UX, wording). Plus la spec est precise sur le *quoi* et floue sur le *comment*, moins il y a de pivots en cours de route
- **TipTap + Turbo Stream** : ne JAMAIS utiliser autosubmit (replace form entier) avec un editeur TipTap. Toujours utiliser des turbo_stream cibles qui ne touchent pas le conteneur de l'editeur
- **JSONB + hidden field** : toujours prevoir un custom setter `field=` qui parse JSON string quand un hidden field alimente une colonne JSONB
- **Flipper vs colonne** : si le flag est lie a l'objet lui-meme (pas a un acteur/procedure), une colonne boolean est plus simple qu'un Flipper
- **Proximite UX** : les champs de test/validation doivent etre visuellement adjacents aux elements qu'ils testent, pas dans une section separee
- **Granularite commits** : si 3 commits touchent les memes fichiers et sont interdependants, c'est 1 commit
- **DSFR tables injectees dynamiquement** : le MutationObserver DSFR initialise correctement les `.fr-table` injectees via turbo_stream (ajoute `data-fr-js-table=true`), pas besoin de hack

## Permissions bloquantes (demandees interactivement)

| Permission | Pourquoi |
|---|---|
| `Agent(Explore)` | Recherche du pattern used_by_routing_rules — refuse par l'utilisateur |

## Actions
- [ ] Ajouter dans feature-spec : section "Patterns TipTap" documentant l'incompatibilite autosubmit/TipTap et le besoin de route dediee -> `.claude/skills/feature-spec/`
- [ ] Ajouter dans feature-spec : regle "JSONB + hidden field = custom setter obligatoire" -> `.claude/skills/feature-spec/`
- [ ] Ajouter dans feature-spec : regle "evaluer Flipper vs colonne boolean selon le porteur du flag" -> `.claude/skills/feature-spec/`
- [ ] Ajouter dans feature-plan : regle "ne pas decouper en commits separes si memes fichiers et interdependants" -> `.claude/skills/feature-plan/`
- [ ] Ajouter dans feature-spec : regle UX "champs de test adjacents aux elements testes" -> `.claude/skills/feature-spec/`
