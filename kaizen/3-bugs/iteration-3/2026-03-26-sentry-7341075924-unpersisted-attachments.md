# Kaizen -- Crash attachment_path(nil) sur commentaire avec validation échouée
Date: 2026-03-26 | Skill: bugfix | Score: 8/10

## Ce qui s'est passé
- Sentry #7341075924 : `ActionController::UrlGenerationError` dans `create_commentaire`
- Root cause : `FileFieldComponent` rendait des attachments non-persistés (id: nil) après échec de validation commentaire avec direct upload
- Régression introduite par migration V1 (EditComponent) → V2 (ButtonUploaderComponent) → V3 (FileFieldComponent)
- Le guard `if attachment.persisted?` de la V1 avait été perdu lors de la migration
- Fix : ajout `.select(&:persisted?)` dans `FileFieldComponent#initialize`
- PR : https://github.com/demarche-numerique/demarche.numerique.gouv.fr/pull/12877

## Ce qui s'est bien passé
- Investigation rapide via la stack trace Sentry — root cause identifiée sans lancer d'agents parallèles
- Remontée dans l'historique git pour comprendre la régression (V1 → V2 → V3) — a permis de confirmer le fix
- Test composant simple et ciblé (unpersisted attachment) plutôt qu'un test controller lourd avec simulation direct upload
- TDD Red/Green propre : test échoue → fix 1 ligne → test passe

## Ce qui s'est mal passé
- Premier test (controller spec) ne reproduisait pas le bug car `fixture_file_upload` ne simule pas le direct upload
- Tentative de simulation direct upload avec `blob.signed_id` — surengineering, le test composant était plus simple
- Temps perdu sur le test controller avant de pivoter vers le test composant
- **Historique git trop superficiel** : Claude s'est arrêté au commit précédent (V2 ButtonUploaderComponent) sans remonter plus loin. Il a fallu que l'utilisateur demande explicitement "remonte plus tôt encore" pour découvrir la V1 (EditComponent/MultipleComponent) qui contenait le guard `persisted?`. Sans cette demande, on aurait conclu que le guard n'avait jamais existé

## Ce qu'on a appris
- Les controller specs sans `render_views` ne testent pas le rendu des composants — le bug était invisible
- `fixture_file_upload` ≠ direct upload : en prod les blobs sont uploadés avant le submit, le form envoie un `signed_id`
- Pour tester un bug de composant, tester directement le composant est plus rapide et plus ciblé que de remonter tout le flow controller
- Pattern de régression classique : un guard défensif dans un ancien composant est perdu lors d'une réécriture/unification

## Permissions bloquantes (demandées interactivement)

| Permission | Pourquoi |
|---|---|
| Aucune | - |

## Actions
- [ ] Ajouter dans le skill bugfix un pattern "Régression par perte de guard" : lors d'une migration de composant, vérifier les guards défensifs de l'ancien code
- [ ] Ajouter dans le skill bugfix une note : préférer les tests composants aux tests controller pour les bugs de rendu
- [ ] Ajouter dans le skill bugfix une règle d'investigation historique : lors de l'analyse git, ne pas s'arrêter au commit précédent — remonter au moins 2-3 générations de refactoring pour retrouver les guards/comportements défensifs originaux. Toujours chercher le "comment c'était avant la réécriture"
