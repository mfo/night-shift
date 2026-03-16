# Quickstart — Boot sequence autonome

**Input :** un fichier spec (ex: `spec/models/dossier_spec.rb`)

---

## Phase 1 : Créer le worktree (depuis le repo principal)

L'agent crée le worktree, puis **s'arrête** et donne la commande à l'utilisateur pour se relancer dans le worktree. Aucun `cd` — l'agent travaille toujours depuis son `cwd`.

```bash
# 1. Dériver le nom depuis le fichier spec
#    spec/models/dossier_spec.rb → dossier-spec
NOM="dossier-spec"

# 2. Créer le worktree
git worktree add ../demarches-simplifiees.fr-perf-$NOM main

# 3. Installer le hook DB
/Users/mfo/dev/night-shift/hooks/worktree/install.sh ../demarches-simplifiees.fr-perf-$NOM

# 4. Créer la branche dans le worktree (déclenche le hook → crée la DB)
git -C ../demarches-simplifiees.fr-perf-$NOM checkout -b perf/$NOM
```

Puis **afficher à l'utilisateur** :

```
Worktree prêt. Lance Claude depuis le worktree :

  cd ../demarches-simplifiees.fr-perf-$NOM && claude
```

**STOP — ne pas continuer.** L'utilisateur relance Claude dans le worktree.

---

## Phase 2 : Init (depuis le worktree)

L'agent détecte qu'il est dans un worktree (`git rev-parse --show-toplevel` ≠ repo principal). Il initialise l'environnement :

```bash
bundle check || bundle install
bin/rails db:test:prepare  # ⚠️ JAMAIS db:schema:load (PostGIS casse)
bundle exec spring start   # élimine le boot ~3s par run
```

Puis enchaîner directement sur l'étape 1 du workflow (profiling baseline).

---

## Commandes de référence

### Lancer un fichier spec (temps)

```bash
bundle exec spring rspec spec/path/to/file_spec.rb
```

**Sans `COVERAGE=true`** — l'overhead SimpleCov fausse les mesures (5-15%).

### Lancer un fichier spec (coverage)

```bash
rm -f coverage/.resultset.json  # éviter accumulation entre runs
COVERAGE=true bundle exec spring rspec spec/path/to/file_spec.rb
```

### Extraire le % coverage depuis SimpleCov

```bash
cat coverage/.resultset.json | ruby -rjson -e '
  data = JSON.parse(STDIN.read)
  # Only count files actually exercised (at least one line hit)
  touched = data.values.first["coverage"].select { |_path, info|
    info["lines"]&.any? { |l| l && l > 0 }
  }
  lines = touched.values.flat_map { |f| f["lines"] }.compact
  covered = lines.count { |l| l && l > 0 }
  total = lines.count { |l| !l.nil? }
  puts "Coverage: #{(covered.to_f / total * 100).round(2)}%"
'
```

---

## Protocole de mesure

1. **1 warm-up** (ignoré)
2. **3 runs**, prendre la **médiane**
3. Seuil de gain : **>= 5% ET >= 0.5s en absolu**

---

## Phase 3 : Cleanup (après kaizen)

```bash
bundle exec spring stop
```

L'agent ne fait **jamais** le cleanup du worktree — c'est l'humain qui décide quand le supprimer.

```bash
# Depuis le repo principal :
cd /Users/mfo/dev/demarches-simplifiees.fr
git worktree remove ../demarches-simplifiees.fr-perf-$NOM
```
