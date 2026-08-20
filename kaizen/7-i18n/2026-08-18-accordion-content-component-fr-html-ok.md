# Kaizen: i18n-hardcoded OK — AccordionContentComponent

**Date** : 2026-08-18
**Session** : 11 min, 104 assistant messages, 34 Bash calls
**Modèle** : deepseek-v4-flash
**Coût** : ~725k tokens estimés

## Ce qui s'est passé

Le skill `/i18n-hardcoded` a extrait 8 textes français du fichier `app/components/llm/header_component/accordion_content_component.fr.html.erb` (42 lignes, template-only ViewComponent, sans fichier Ruby associé). 3 fichiers modifiés : ERB (remplacement par `t('.key')`), `fr.yml` (nouveau, 8 clés), `en.yml` (nouveau, 8 clés). Tests OK (3 exemples, 0 échecs), commit effectué.

## Bien passé

- **Détection précoce du pattern sidecar YAML** : dès la découverte du composant, le skill a vérifié que `header_component` utilise déjà `t('.how_it_works')` avec des sidecars — la convention a été respectée automatiquement.
- **Recherche de traductions existantes** avant extraction : `grep` sur les 8 textes français dans le repo a confirmé qu'aucune traduction n'existe ailleurs, évitant la duplication.
- **Vérification de correspondance clés ↔ YAML** : après l'écriture des 3 fichiers, une relecture complète a confirmé que chaque `t('.key')` a une entrée dans les 2 YAML — zéro clé oubliée.
- **Apostrophe lint avant tests** : `bundle exec rake lint:apostrophe:fix` exécuté systématiquement avant la validation.
- **PR description complète** : même sans screenshots, le résumé final est clair et structuré (tableau des clés + statut de validation).

## Mal passé

- **34 appels Bash, dont 15 redondants** : multiples `find` pour le même fichier Ruby (inexistant), multiples `find` pour les previews, exploration de routes avec le mot-clé erroné `simplify` (le composant parle d'*amélioration*, pas de simplification). Chaque recherche ajoute 2-3 tours de latence sans valeur ajoutée.
- **Recherche de preview ViewComponent trop large** : le skill a exploré `spec/components/previews`, `app/controllers`, `config/routes` à la recherche d'une preview — mais le composant n'a aucun fichier Ruby, donc aucune preview possible. Cette exploration a coûté ~10 appels Bash et ~15% du temps de session.
- **Vérification serveur redondante** : le skill a lancé `curl localhost:3220` en fin de session alors qu'aucune preview n'existe — le résultat était prévisible (404).
- **Temps de session long (11 min)** pour 8 textes simples : la majorité du temps a été consommée par les recherches exploratoires, pas par l'extraction elle-même.

## Appris

1. **Template-only ViewComponents** (sans `.rb`) ne peuvent pas avoir de preview — le scanner peut sauter toute la phase preview dès la détection de l'absence de fichier Ruby.
2. **Les recherches de routes avec des mots-clés hors contexte** (`simplify` au lieu de `amelioration`) gaspillent des tokens et ajoutent du bruit — le skill devrait utiliser les mots-clés du fichier source pour guider les recherches.
3. **Sidecar YAML** : la convention `.fr.yml` / `.en.yml` au même niveau que le template est la norme — le skill l'a respectée sans hésitation.
4. **Le naming des clés i18n** a suivi un pattern concis et descriptif (`.assistance`, `.ia_description`, `.libelles_description`) — pas de clés trop longues, pas de clés trop courtes.

## Permissions bloquantes

Aucune. Le mode `acceptEdits` a tout autorisé.

## Actions

- **Optimisation skill i18n-hardcoded** : ajouter un early-exit sur la phase preview quand `find -name '*_component.rb'` ne trouve pas de fichier Ruby — sauter `find` dans `app/controllers`, `config/routes`, et `spec/components/previews`.
- **Réduction des appels Bash** : les 3-4 recherches redondantes de la même ressource (ex: `find` pour le même fichier 3 fois) peuvent être consolidées — une seule recherche, stocker le résultat en mémoire.
- **Mots-clés de recherche contextuels** : extraire les mots-clés du fichier source (ex: `amelioration`) pour guider les recherches routes/controllers plutôt que d'utiliser des termes génériques (`simplify`).
- **Seuil de rentabilité** : 8 textes en 11 min = ~1.4 textes/min, 725k tokens pour 8 clés. Le coût est correct mais les recherches exploratoires représentent ~60% du temps — les optimisations ci-dessus peuvent le réduire à ~5 min.

## Score : 7/10

Succès fonctionnel complet mais efficacité dégradée par des recherches exploratoires non ciblées et redondantes. Le pattern d'extraction lui-même (détection sidecar, vérification clés-YAML, lint avant tests) est exemplaire et reproductible.
