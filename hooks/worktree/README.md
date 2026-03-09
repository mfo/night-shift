# Hooks Worktree - Isolation des Bases de Données

## Problème

Quand on travaille avec des git worktrees pour isoler différentes tâches (POCs, features, migrations), on a besoin que chaque worktree ait sa propre base de données de test.

**Sans isolation :**
- Tous les worktrees partagent la même DB test
- Les tests d'un worktree peuvent casser ceux d'un autre
- Impossible de travailler sur plusieurs tâches en parallèle

**Avec isolation :**
- Chaque worktree a sa propre DB : `tps_test_poc_haml`, `tps_test_poc_bugs`, etc.
- Les tests sont complètement isolés
- On peut lancer des tests en parallèle sans conflit

---

## Solution : Hook post-checkout

Le hook `post-checkout` s'exécute automatiquement après chaque checkout de branche dans un worktree.

**Ce qu'il fait :**
1. Détecte qu'on est dans un worktree (pas le repo principal)
2. Génère un nom de DB unique basé sur le nom du worktree
3. Crée un fichier `.env.test.local` avec la config DB spécifique
4. Crée la DB PostgreSQL si elle n'existe pas
5. Charge le schema Rails dans la nouvelle DB

---

## Installation

### 1. Créer le worktree

```bash
cd /path/to/demarche.numerique.gouv.fr
git worktree add -b poc-haml ../demarche.numerique.gouv.fr-poc-haml main
```

### 2. Installer le hook dans le worktree

```bash
cd ../demarche.numerique.gouv.fr-poc-haml

# Créer le répertoire des hooks
mkdir -p .githooks

# Copier le hook
cp /path/to/night-shift/hooks/worktree/post-checkout .githooks/

# Rendre exécutable
chmod +x .githooks/post-checkout

# Configurer git pour utiliser .githooks
git config core.hooksPath .githooks
```

### 3. Tester

```bash
# Checkout d'une branche pour déclencher le hook
git checkout -b test-hook

# Vérifier que la DB a été créée
psql -U tps_test -h localhost -l | grep tps_test_poc_haml

# Vérifier .env.test.local
cat .env.test.local
```

**Sortie attendue :**
```
==> Worktree détecté: demarche.numerique.gouv.fr-poc-haml
==> Configuration de la base de données: tps_test_poc_haml
==> Création de la base de données tps_test_poc_haml
==> Chargement du schema dans tps_test_poc_haml
✓ Configuration worktree terminée!
  → Base de données: tps_test_poc_haml
  → Config: .env.test.local
```

---

## Configuration

Le hook utilise ces conventions de nommage :

**Format du worktree :**
```
demarche.numerique.gouv.fr-{suffixe}
```

**Nom de la DB généré :**
```
tps_test_{suffixe_avec_underscores}
```

**Exemples :**
| Nom du worktree | DB créée |
|-----------------|----------|
| `demarche.numerique.gouv.fr-poc-haml` | `tps_test_poc_haml` |
| `demarche.numerique.gouv.fr-poc-bugs` | `tps_test_poc_bugs` |
| `demarche.numerique.gouv.fr-migration-phase2` | `tps_test_migration_phase2` |

---

## Prérequis

**PostgreSQL configuré :**
```bash
# Créer l'utilisateur test si nécessaire
createuser -s tps_test

# Vérifier que psql fonctionne
psql -U tps_test -h localhost -l
```

**Rails configuré :**
- Fichier `.env.test` avec config DB par défaut
- `config/database.yml` qui lit les variables d'env

---

## Dépannage

### Le hook ne s'exécute pas

```bash
# Vérifier que le hook est exécutable
ls -la .githooks/post-checkout

# Vérifier la config git
git config core.hooksPath

# Forcer l'exécution manuelle
.githooks/post-checkout prev_head new_head 1
```

### La DB ne se crée pas

```bash
# Vérifier les credentials PostgreSQL
psql -U tps_test -h localhost -c "SELECT 1"

# Créer la DB manuellement
createdb -U tps_test -h localhost tps_test_poc_haml

# Charger le schema
RAILS_ENV=test bundle exec rails db:schema:load
```

### .env.test.local n'est pas pris en compte

```bash
# Vérifier que dotenv charge .env.test.local
cat config/application.rb | grep Dotenv

# Vérifier l'ordre de chargement (doit être après .env.test)
# .env.test.local doit override .env.test
```

---

## Nettoyage

### Supprimer un worktree

```bash
# Depuis le repo principal
cd /path/to/demarche.numerique.gouv.fr
git worktree remove ../demarche.numerique.gouv.fr-poc-haml

# Supprimer la DB associée
dropdb -U tps_test -h localhost tps_test_poc_haml
```

### Lister toutes les DBs de worktrees

```bash
psql -U tps_test -h localhost -l | grep tps_test_
```

### Supprimer toutes les DBs de worktrees

```bash
# ATTENTION: Supprime toutes les DBs commençant par tps_test_
psql -U tps_test -h localhost -l -t | cut -d '|' -f 1 | grep tps_test_ | xargs -I {} dropdb -U tps_test -h localhost {}
```

---

## Intégration avec Night Shift

Ce hook est un **building block** du projet Night Shift.

**Pourquoi c'est critique :**
- Les agents IA travaillent dans des worktrees isolés
- Chaque POC doit avoir sa propre DB de test
- Sans isolation, un POC peut casser les tests d'un autre
- Permet de lancer plusieurs agents en parallèle

**Workflow Night Shift :**
1. Créer un worktree pour le POC : `git worktree add -b poc-X ...`
2. Le hook configure automatiquement la DB isolée
3. L'agent IA travaille dans un environnement propre
4. Les tests du POC n'interfèrent pas avec le repo principal
5. Cleanup facile : `git worktree remove` + `dropdb`

---

## Améliorations Possibles

**Automatiser l'installation :**
```bash
# Script bin/worktree-create qui :
# 1. Crée le worktree
# 2. Installe le hook automatiquement
# 3. Configure git hooks path
# 4. Vérifie la DB
```

**Support d'autres SGBD :**
- MySQL : adapter les commandes createdb/dropdb
- SQLite : créer un fichier DB unique par worktree

**Cleanup automatique :**
- Hook post-worktree-remove qui supprime la DB
- Script qui détecte les DBs orphelines

---

**Dernière mise à jour :** 2026-03-09
