# Quickstart — Boot sequence autonome

**Input :** un fichier spec (ex: `spec/models/dossier_spec.rb`)

---

## Phase 1 : Setup (worktree + DB)

```bash
# 1. Dériver le nom depuis le fichier spec
#    spec/models/dossier_spec.rb → dossier-spec
NOM="dossier-spec"

# 2. Créer le worktree (sans branche — on checkout après le hook)
cd /Users/mfo/dev/demarches-simplifiees.fr
git worktree add ../demarches-simplifiees.fr-perf-$NOM main

# 3. Installer le hook DB
/Users/mfo/dev/night-shift/hooks/worktree/install.sh /Users/mfo/dev/demarches-simplifiees.fr-perf-$NOM

# 4. Se placer dans le worktree et créer la branche (déclenche le hook → crée la DB)
cd /Users/mfo/dev/demarches-simplifiees.fr-perf-$NOM
git checkout -b perf/$NOM

# 5. Vérifier que tout est prêt
bundle check || bundle install
bin/rails db:test:prepare  # ⚠️ JAMAIS db:schema:load (PostGIS casse)
```

---

## Phase 2 : Commandes de référence

### Lancer un fichier spec (temps)

```bash
bundle exec rspec spec/path/to/file_spec.rb
```

**Sans `COVERAGE=true`** — l'overhead SimpleCov fausse les mesures (5-15%).

### Lancer un fichier spec (coverage)

```bash
COVERAGE=true bundle exec rspec spec/path/to/file_spec.rb
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
# Revenir au repo principal
cd /Users/mfo/dev/demarches-simplifiees.fr
git worktree remove ../demarches-simplifiees.fr-perf-$NOM
```

L'agent ne fait **jamais** le cleanup — c'est l'humain qui décide quand supprimer le worktree.
