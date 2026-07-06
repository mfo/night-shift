# Patterns flaky-test-fix


## Auto-discovered pitfalls

<!-- Managed by autolearn. Review via kaizen synth. -->

### AL-1 (2026-07-06 14:08)

Dans patterns.md, ajouter une section sur les permissions requises pour le diagnostic de flaky tests : pré-autoriser les commandes 'bundle exec rspec', 'bundle show', 'bundle list', 'gem which', 'find', 'sed' dans la configuration allowed_commands du SKILL.md. Alternativement, instruire l'agent d'utiliser les outils Read/Grep/LSP plutôt que Bash pour explorer le code source des gems (capybara), afin de contourner les permission prompts sans consommer de contexte.
