---
name: n1-query-fix
description: "Fix N+1 queries detected by Prosopite and Skylight. Use in autolearn mode with backlog items grouped by model/concern file."
allowed-tools: Bash(git status:*), Bash(git add:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(git blame:*), Bash(git apply:*), Bash(grep:*), Bash(find:*), Bash(rm -f tmp/prosopite:*), Bash(bundle install), Bash(bundle exec rspec:*), Bash(bundle exec rubocop:*), Bash(echo:*), Bash(ls:*), Bash(cat:*), Edit(app/*), Edit(config/*), Write(app/*), Write(pr-description.md)
---

# Fix N+1 queries

**Contexte :** Corriger les requetes N+1 detectees par Prosopite (tests) et Skylight (production) dans un fichier model/concern Rails.

**Input :**
- Fichier a traiter : `$ARGUMENTS` (ex: `app/models/dossier.rb` ou `app/models/concerns/dossier_searchable.rb`)
- Contexte de production : `.skill-context.json` (optionnel, contient les donnees Skylight)

**Regles Bash** :
- Pas de `$()` (command substitution)
- Pas de `;` ou `&&` pour chainer
- 1 commande simple = 1 appel Bash
- Ne JAMAIS utiliser `git -C` — le working directory est deja le repo cible

---

## Etape 0 : Setup Prosopite (mode log)

Appliquer le patch Prosopite pour activer la detection N+1 dans les tests, en **mode log** (pas raise).

1. **Appliquer le patch** :
   ```bash
   git apply ~/dev/night-shift/.claude/skills/n1-query-fix/prosopite-setup.patch
   ```
   Si le patch est deja applique (erreur "patch does not apply"), passer a l'etape suivante.

2. **Desactiver raise, activer le log fichier** :
   Editer `config/environments/test.rb` — remplacer le bloc Prosopite par :
   ```ruby
   config.after_initialize do
     Prosopite.rails_logger = true
     Prosopite.raise = false
     Prosopite.prosopite_logger = Logger.new("tmp/prosopite-scan.log")
   end
   ```
   Ceci permet aux tests de **passer** meme avec des N+1, tout en capturant les stack traces.

3. **Installer les gems** :
   ```bash
   bundle install
   ```

4. **Ne PAS commiter ce setup** — il sera revert quand le worktree sera nettoye.
   Le commit du fix N+1 ne doit contenir que les changements de code applicatif.

## Etape 1 : Lire le contexte

1. **Lire le fichier cible** (`$ARGUMENTS`)
2. **Lire `.skill-context.json`** s'il existe — il contient :
   ```json
   {
     "source_file": "app/models/dossier.rb",
     "n1_patterns": [
       {
         "table": "etablissements",
         "sql_pattern": "SELECT etablissements.* FROM etablissements WHERE etablissements.dossier_id = ?",
         "endpoints": [
           {
             "name": "Users::DossiersController#index",
             "rpm": 1836,
             "p95_ms": 692,
             "avg_reps": 50,
             "waste_ms": 2700
           }
         ],
         "association": "etablissement",
         "test_files": ["spec/models/dossier_spec.rb"]
       }
     ],
     "total_waste_ms": 5400,
     "skylight_url": "https://..."
   }
   ```
3. **Prioriser les patterns par `waste_ms` decroissant** — fixer les plus couteux en premier

## Etape 2 : Triage prod vs test

Lancer les specs ciblees avec Prosopite en mode log :

```bash
rm -f tmp/prosopite-scan.log
bundle exec rspec spec/controllers/<controller>_spec.rb
```

Puis lire le log Prosopite :
```bash
cat tmp/prosopite-scan.log
```

**Classifier chaque N+1 selon son call stack** :

- **PROD** : le call stack remonte dans `app/` (controller, model, view, service).
  → C'est un vrai N+1 qui impacte les utilisateurs. **A fixer.**
- **TEST** : le call stack ne sort pas de `spec/` (factory, `before`, `let`, setup).
  → C'est du bruit de test. **A ignorer.**

Pour classifier, lire la stack trace Prosopite :
```
N+1 queries detected:
  SELECT "etablissements".* FROM "etablissements" WHERE ...
  ↳ app/models/dossier.rb:42:in `etablissement`     ← PROD (app/)
    app/controllers/users/dossiers_controller.rb:15
    spec/controllers/users/dossiers_controller_spec.rb:88
```
vs
```
N+1 queries detected:
  SELECT "groupe_instructeurs".* FROM "groupe_instructeurs" WHERE ...
  ↳ spec/controllers/instructeurs/procedures_controller_spec.rb:85  ← TEST (spec/)
    spec/spec_helper.rb:12
```

**Regle** : si AUCUN N+1 PROD n'est identifie → **abandonner l'item**.
Ecrire `pr-description.md` avec la raison :
```markdown
## Skip

Aucun N+1 de production detecte. Les N+1 proviennent uniquement du setup de test (factories, before blocks).
Prosopite detecte N patterns, tous dans spec/.
```
Puis ne PAS commiter et terminer.

## Etape 3 : Analyser les N+1 PROD

Pour chaque pattern PROD uniquement :

1. **Trouver l'association ActiveRecord** correspondante dans le model :
   - Table `etablissements` → `has_one :etablissement` ou `belongs_to :etablissement`
   - Table `active_storage_attachments` → `has_one_attached` / `has_many_attached`
   - Table `procedure_revision_types_de_champ` → association via join/through

2. **Trouver les call sites** : ou cette association est chargee sans eager loading
   ```bash
   grep -rn "\.etablissement" app/models/ app/controllers/ app/views/ app/graphql/
   ```

3. **Identifier la strategie de fix** :
   - **`includes`/`preload`** : dans le scope ou le controller qui charge la collection
   - **`strict_loading`** : si l'association ne doit jamais etre lazy-loaded
   - **scope avec `includes`** : ajouter un scope au model (ex: `scope :with_etablissement, -> { includes(:etablissement) }`)
   - **GraphQL** : utiliser `AssociationLoader` / `BatchLoader` / `dataloader`

## Etape 4 : Appliquer les fixes

Ne fixer que les N+1 PROD. Ne PAS toucher aux tests pour faire taire Prosopite.

1. **Modifier le code applicatif** :
   - Si c'est un scope existant utilise dans un controller : ajouter `includes(:association)`
   - Si c'est un GraphQL resolver : utiliser le pattern dataloader/batch
   - Si c'est une vue qui itere : remonter le `includes` dans le controller
   - **Ne PAS ajouter `includes` dans le model par defaut** (surcharge toutes les queries)

2. **Privilegier les scopes nommes** :
   ```ruby
   # Bon : scope explicite
   scope :with_etablissement, -> { includes(:etablissement) }

   # Mauvais : default_scope avec includes
   default_scope { includes(:etablissement) }
   ```

3. **Pour les associations polymorphiques ou complexes** :
   - Utiliser `preload` au lieu de `includes` (evite les LEFT JOIN inutiles)
   - Pour ActiveStorage : `with_attached_<nom>`

## Etape 5 : Verifier l'absence de regression

1. **Lancer les tests lies** :
   ```bash
   bundle exec rspec spec/models/<model>_spec.rb
   ```
   Si le contexte mentionne des `test_files`, les lancer aussi :
   ```bash
   bundle exec rspec spec/controllers/<controller>_spec.rb
   ```

2. **Verifier que Prosopite ne detecte plus le N+1 PROD** :
   - Les tests doivent passer
   - Les N+1 TEST peuvent encore etre detectes — c'est OK, on ne les fixe pas

3. **Rubocop** :
   ```bash
   bundle exec rubocop <fichiers_modifies>
   ```

## Etape 6 : Commit

```bash
git add <fichiers_modifies>
git commit --no-gpg-sign -m "perf(<model>): fix N+1 on <association> — <contexte>"
```

Message de commit :
- Prefixe `perf(<scope>):`
- Mentionner l'association fixee
- Si le contexte Skylight existe : mentionner le waste elimine (ex: "saves ~2700ms/req on DossiersController#index")
- **Ne commiter que des fichiers app/ et config/** (pas de modifs de spec/ pour faire taire Prosopite)

Un commit par pattern N+1 fixe (ou grouper si les fixes sont dans le meme fichier/scope).

## Etape 7 : pr-description.md (OBLIGATOIRE)

**Toujours ecrire `pr-description.md`** a la racine du worktree, meme si un seul pattern est fixe :

```markdown
---
title: "Tech: fix N+1 sur <association> dans <Controller>"
---

# Probleme

Requetes N+1 **de production** detectees sur `<model>` par Prosopite et Skylight.

Triage : N patterns PROD (call stack dans app/) / M patterns TEST ignores.

# Solution

Skill [`/n1-query-fix`](https://github.com/mfo/night-shift/blob/main/.claude/skills/n1-query-fix/SKILL.md)

### Patterns corriges (PROD uniquement)

| Association | Table | Strategy | Endpoint impacte | RPM | Waste estime |
|-------------|-------|----------|------------------|-----|--------------|
| `etablissement` | etablissements | `includes` dans scope | DossiersController#index | 1836 | ~2700ms/req |

### Validation

- [x] Tests passes (rspec)
- [x] Rubocop OK
- [x] Seuls des fichiers app/ et config/ sont commites

Generated with [Claude Code](https://claude.com/claude-code)
```

---

## Regles critiques

1. **PROD only** : ne fixer que les N+1 dont le call stack passe par `app/`. Les N+1 de test setup (factories, before blocks) ne sont PAS des bugs de perf — les ignorer.
2. **Ne pas modifier les specs pour faire taire Prosopite** : pas de `Prosopite.pause`, pas de Preloader dans le setup, pas de `update_column` dans les fixtures. Ces changements n'apportent rien en prod.
3. **Abandonner si aucun N+1 PROD** : ecrire un pr-description.md "Skip" et terminer sans commit.
4. **Ne pas casser les queries existantes** : `includes` change le SQL genere. Verifier que les tests passent.
5. **Pas de default_scope** : jamais ajouter `includes` dans un `default_scope`.
6. **Preload vs Includes** : utiliser `preload` pour les associations polymorphiques ou quand on ne filtre pas sur l'association.
7. **1 fichier source = 1 run** : traiter tous les N+1 du fichier cible, mais ne pas elargir a d'autres fichiers.
8. **GraphQL = pattern specifique** : les resolvers GraphQL necessitent des batch loaders, pas des `includes` classiques.
9. **Lire le contexte Skylight** : `.skill-context.json` contient les donnees de production. L'utiliser pour prioriser et documenter.
