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

### AL-2 (2026-05-15 08:38)

## Dev Server in Worktree

- Le skill doit configurer un PORT unique par worktree (ex: PORT=3000+hash du nom de branche) AVANT de lancer bin/dev
- Ajouter `Bash(bin/dev:*)` et `Bash(bin/setup:*)` dans les allowed-tools du skill
- Ne JAMAIS supposer que le port 3000 ou 3210 est libre : toujours vérifier avec `lsof -i :PORT` avant de lancer
- Si un serveur tourne déjà sur le port cible depuis un AUTRE worktree, choisir un port libre (3100-3999) et configurer .env.development.local avec ce port
- Le fichier config/initializers/dev_auto_login.rb peut ne pas exister : vérifier son existence avant de grep dedans, et le créer si nécessaire pour le auto-login dev
- Ajouter `Bash(stat:*)`, `Bash(lsof:*)` dans les allowed-tools pour le diagnostic serveur

### AL-3 (2026-06-16 11:15)

Dans patterns.md, ajouter une section sur les prérequis et fallbacks :

## Prérequis infrastructure

Avant d'exécuter une migration, vérifier :
- Si `config/initializers/dev_auto_login.rb` n'existe pas, **ne pas appeler dev-auto-login** et passer directement à l'étape suivante.
- Si `WaitForMcpServers` n'est pas disponible (tool inexistant), utiliser `sleep 3` comme fallback ou ignorer l'attente.
- Si Playwright MCP n'est pas configuré (`claude mcp list` ne liste pas `playwright` ou le fichier de conf MCP est absent), **ignorer la validation visuelle** et se baser uniquement sur le diff texte ERB/HAML. Ne pas bloquer la migration sur l'absence de Playwright.
