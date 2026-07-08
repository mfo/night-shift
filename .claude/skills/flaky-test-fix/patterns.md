# Patterns flaky-test-fix


## Auto-discovered pitfalls

<!-- Managed by autolearn. Review via kaizen synth. -->

### AL-1 (2026-07-06 14:08)

Dans patterns.md, ajouter une section sur les permissions requises pour le diagnostic de flaky tests : pré-autoriser les commandes 'bundle exec rspec', 'bundle show', 'bundle list', 'gem which', 'find', 'sed' dans la configuration allowed_commands du SKILL.md. Alternativement, instruire l'agent d'utiliser les outils Read/Grep/LSP plutôt que Bash pour explorer le code source des gems (capybara), afin de contourner les permission prompts sans consommer de contexte.

### AL-2 (2026-07-08 15:31)

Dans patterns.md, ajouter :

## Permission Bash en mode autonome

Lorsque le skill 'flaky-test-fix' s'exécute en mode autonome, les commandes Bash (notamment `bundle exec rspec`, `bash <path>/verify-flaky.sh`) peuvent être bloquées par le système de permissions. 

Avant de lancer les commandes, vérifier ou configurer les permissions dans `.claude/settings.json` :

```
"allowList": [
  ".*bundle exec rspec.*",
  ".*verify-flaky\.sh.*",
  ".*bash .*"
]
```

Si les permissions ne peuvent pas être pré-configurées (environnement restreint), utiliser plutôt les outils Read/Edit/Grep pour analyser le test sans exécuter de commandes Bash, puis proposer le fix sous forme de patch sans exécution.
