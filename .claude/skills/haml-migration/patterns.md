# Patterns haml-migration


## Auto-discovered pitfalls

<!-- Managed by autolearn. Review via kaizen synth. -->

### AL-1 (2026-05-15 08:33)

Dans patterns.md ou le prompt du skill haml-migration, ajouter :

## Dev Auto-Login

- Ne JAMAIS tenter de configurer le dev-auto-login depuis le skill haml-migration.
- Si le dev-auto-login n'est pas déjà configuré (fichier config/initializers/dev_auto_login.rb absent), PASSER directement à la migration HAML→ERB sans screenshots.
- La priorité absolue est la conversion du fichier HAML en ERB. Les screenshots sont un bonus, pas un prérequis.
- Si Playwright échoue ou si l'auto-login n'est pas disponible, continuer la migration sans validation visuelle.

## Ordre des opérations

1. Convertir le fichier HAML en ERB (OBLIGATOIRE)
2. Lancer les linters et tests (OBLIGATOIRE)
3. Tenter les screenshots AVANT/APRÈS (OPTIONNEL - ne pas bloquer si échec)
