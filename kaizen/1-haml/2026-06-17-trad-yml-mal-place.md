---
status: traité
date_synth: 2026-06-17
---
# Kaizen — Fichier de traduction YML mal placé dans la migration HAML
Date: 2026-06-17 | Skill: haml-migration | Score: 5/10

## Ce qui s'est passé
- Migration batch haml-migration sur CopyButtonComponent (PR #13306)
- Le skill a créé `app/components/dsfr/copy_button_component.yml` à la racine du dossier parent
- Le fichier aurait dû être `app/components/dsfr/copy_button_component/copy_button_component.fr.yml` (convention ViewComponent sidecar)
- Le skill a aussi créé un `.en.yml` dans le bon dossier, mais le `.fr.yml` n'est pas au bon endroit
- Review d'ELT : "juste un fichier de trad à supprimer sinon ça a l'air ok"

## Ce qui s'est bien passé
- La migration ERB elle-même est correcte
- Le `t('.copy_confirmation')` fonctionne avec la convention sidecar

## Ce qui s'est mal passé
- Le modèle local (ds4) ne comprend pas la convention Rails/ViewComponent pour les fichiers de traduction sidecar
- Il a créé un fichier à la racine au lieu du dossier sidecar
- Convention : les traductions ViewComponent vivent dans `component_name/component_name.LOCALE.yml`, pas à côté du dossier

## Ce qu'on a appris
- Convention ViewComponent sidecar translations :
  - `app/components/namespace/my_component/my_component.fr.yml` (avec locale dans le nom)
  - PAS `app/components/namespace/my_component.yml` (sans locale, hors du dossier)
- Le `t('.key')` dans un ViewComponent résout via le fichier sidecar dans le dossier du composant
- Si le fichier `.fr.yml` existe déjà dans le dossier sidecar, ne PAS en créer un nouveau
- Rails avec Sidekiq/background jobs : les traductions doivent être dans des fichiers avec la locale dans le nom (`.fr.yml`, `.en.yml`) pour que `I18n.with_locale` fonctionne correctement

## Actions
- [ ] Ajouter un pattern dans patterns.md : ne jamais créer de fichier de traduction, les composants utilisent des fichiers sidecar existants
