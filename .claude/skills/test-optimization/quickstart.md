# Quickstart

**Input :** un fichier spec — `$ARGUMENTS` (ex: `spec/models/dossier_spec.rb`)

Le worktree, la DB et les dépendances sont déjà prêts (hook post-checkout). Première action :

```bash
bundle exec spring start
```

Puis enchaîner sur l'étape 1 du workflow (profiling baseline).

---

## Commandes de référence

### Lancer un fichier spec (temps)

```bash
bundle exec spring rspec spec/path/to/file_spec.rb
```

**Sans `COVERAGE=true`** — l'overhead SimpleCov fausse les mesures (5-15%).

### Lancer un fichier spec (coverage)

```bash
.claude/skills/test-optimization/coverage.sh spec/path/to/file_spec.rb
```

Ce script fait tout : clear le `.resultset.json`, lance le spec avec `COVERAGE=true`, et affiche le `Coverage: XX%`.

---

## Protocole de mesure

1. **1 warm-up** (ignoré)
2. **3 runs**, prendre la **médiane**
3. Seuil de gain : **>= 5% ET >= 0.5s en absolu**
