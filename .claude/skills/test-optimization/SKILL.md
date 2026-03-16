---
name: test-optimization
description: Optimiser un fichier spec — profiler, explorer, optimiser, vérifier, documenter
---

# Test Optimization

**Input :** chemin vers un fichier spec (ex: `spec/models/dossier_spec.rb`)
**Output :** commits granulaires + kaizen

---

## Prérequis

- Worktree isolé avec DB dédiée (hook post-checkout)
- Ne jamais push
- Catalogue de techniques communes (lecture seule) : `.claude/skills/test-optimization/patterns.md`
- Catalogue de techniques system specs (lecture seule) : `.claude/skills/test-optimization/patterns-system.md` — **à consulter en plus** quand le fichier cible est dans `spec/system/`
- Template kaizen : `.claude/skills/test-optimization/template.md`

---

## Workflow

### Étape 0 : Setup (worktree + DB)

Suivre `quickstart.md` Phase 1 : créer le worktree, installer le hook, checkout la branche (déclenche la DB), vérifier bundle + migrations.

### Étape 1 : Profiler (baseline locale)

Voir `quickstart.md` pour les commandes exactes (runs, coverage, extraction %).

1. **Temps** : 1 warm-up + 3 runs (médiane) — **SANS** `COVERAGE=true`
2. **Coverage** : vérifier d'abord la colonne `Coverage %` dans l'inventaire (`slow-tests-inventory.md`). Si elle est remplie, utiliser cette valeur comme baseline. Sinon, 1 run `COVERAGE=true` puis extraire le % depuis `coverage/.resultset.json` et mettre à jour l'inventaire.

C'est la baseline (temps + coverage). Les temps CI sont indicatifs, le local fait foi.

**Si un run de baseline est rouge** → marquer le fichier comme `flaky` dans l'inventaire, écrire un kaizen minimal, et passer au fichier suivant.

### Étape 2 : Lire et comprendre

1. Lire le fichier spec entier
2. Lire le code source testé (modèles, services, controllers appelés)
3. Identifier les causes de lenteur :
   - Factories lourdes (trop de `create`)
   - N+1 queries
   - Appels API non stubés
   - Setup inutile
   - Sleep/wait
   - Assertions/tests dupliqués
   - Code source lent (root cause)

### Étape 3 : Explorer, vérifier, décider

Pour chaque technique du catalogue (communes + system si `spec/system/`) :

1. **Appliquer** la technique
2. **Vérifier tests + couverture** (un seul run) :
   ```bash
   COVERAGE=true bundle exec rspec spec/path/to/file_spec.rb
   ```
   - Si un test casse → rollback et passer à la technique suivante.
   - Comparer la coverage avec la baseline courante (initiale à l'étape 1, puis mise à jour après chaque commit). **Toute baisse = rollback immédiat.**
3. **Mesurer le gain** (1 warm-up + 3 runs, médiane, **SANS** `COVERAGE=true` — l'overhead fausserait les temps) :
   ```bash
   bundle exec rspec spec/path/to/file_spec.rb
   ```
   - **>= 5% ET >= 0.5s** → commit (étape 4), puis nouvelle baseline = cette mesure
   - **< seuil** → rollback, noter dans le kaizen comme tentative échouée
4. **Passer à la technique suivante** sur la nouvelle baseline
5. **Quand toutes les techniques sont essayées** → kaizen (étape 5), mettre à jour l'inventaire (étape 6), et stop

Tu es libre d'explorer au-delà du catalogue : modifier le code source, supprimer des `it`/`describe` dupliqués, réorganiser le setup. Documenter ce qui est tenté, **même les échecs**.

**Si tu modifies du code source** (pas seulement le fichier spec) : lancer aussi les specs directement liées (ex: si tu modifies `app/models/dossier.rb`, lancer `bundle exec rspec spec/models/dossier_spec.rb`). La CI rattrapera le reste.

**Kill switch** : 20min max par fichier. Si dépassé → terminer la technique en cours, rollback si non commitée, écrire un kaizen avec `status: echec`, et s'arrêter.

### Étape 4 : Commit (granulaire)

1 commit par technique appliquée. Format :

```
perf(tests): [technique] — fichier_spec.rb

- Temps avant : Xs → après : Ys (gain Z%)
- [explication de ce qui a été changé et pourquoi]
```

### Étape 5 : Kaizen

**Toujours écrire un kaizen** — même en cas d'échec (aucune technique n'a fonctionné).

Écrire dans `/Users/mfo/dev/night-shift/kaizen/2-test-optimization/<agent-id>/kaizen.md` basé sur le template `.claude/skills/test-optimization/template.md`.

Remplir les champs obligatoires :
- `agent-id` : nom du fichier spec (ex: `dossier-spec`)
- `spec-file` : chemin complet du fichier spec
- `status` : `succes` (au moins 1 commit), `echec` (aucune technique viable), ou `flaky` (baseline rouge)
- Temps avant / après (médiane 3 runs)
- Technique(s) appliquée(s) (depuis le catalogue)
- Technique(s) tentées sans succès (+ raison)
- Piège(s) rencontré(s)
- Blocages (ce qui a empêché d'avancer)
- Actions suggérées pour la synthèse

Auto-remplir "Ce qu'on a appris". Si tu as besoin de quelque chose (tooling, MCP, conseil) → demande une fois. On est une équipe.

### Étape 6 : Mettre à jour l'inventaire

Mettre à jour `pocs/2-test-optimization/slow-tests-inventory.md` avec les colonnes avant/après/gain pour le fichier traité.

---

## Règles dures

- ❌ Ne jamais skip un test
- ❌ Ne jamais push
- ❌ **Pas de perte de couverture** : supprimer du code dupliqué qui teste le même comportement = OK. Supprimer du code qui couvre un cas unique = interdit.
- ✅ Tests verts pour commit (si tests rouges → pas de commit, mais kaizen quand même)
- ⏱️ **20min max par fichier** (kill switch)

## Guidelines (indicatives — tu es un explorateur et un collaborateur)

- Peut modifier le code source si c'est la root cause de la lenteur
- Peut supprimer des assertions, des `it`/`describe` dupliqués
- Peut réorganiser le setup
- Peut appliquer n'importe quelle technique, même hors catalogue
- `patterns.md` est en **lecture seule** — noter les techniques découvertes dans le kaizen
- Documenter les tentatives échouées dans le kaizen
- **Autonome** dans le périmètre des permissions — tu fonces
- **Choix du fichier** : pas de priorisation par lenteur. Prendre les fichiers et techniques de manière aléatoire pour maximiser la découverte de nouvelles approches
- **Collaboratif** : si tu as besoin de quelque chose, demande une fois
- **Mesure** : toujours 1 warm-up + 3 runs, médiane

## Pièges connus (retours kaizen)

### let_it_be : modifiers indisponibles

`reload:` et `refind:` ne fonctionnent **pas** sur ce projet. Le `require 'test_prof/recipes/rspec/let_it_be'` est dans `spec_helper.rb:25`, chargé **avant** Rails. Les modifiers s'enregistrent via un hook qui détecte `ActiveRecord::Base`, absent à ce stade.

**Conséquence :** `let_it_be` ne s'applique qu'aux blocs **read-only** (scopes, queries, méthodes pures). Les blocs qui mutent les objets (`accepter!`, `passer_en_instruction!`, `update`, etc.) ne peuvent pas être convertis sans pollution inter-tests.

### let_it_be : ordre des FK

Avec `let!`, l'ordre de déclaration n'importait pas (eager + lazy). Avec `let_it_be`, l'insertion est séquentielle : **déclarer les dépendances avant les dépendants** (ex: `expert` avant `experts_procedure`).

### DB : ne jamais lancer db:schema:load

PostGIS + libxml2 non linkée sur cette machine → `db:schema:load` échoue sur les extensions → DB vide et irrécupérable. **Toujours utiliser `db:test:prepare`** (quickstart).

### aggregate_failures (T09) : gain marginal

Testé sur dossier_spec — fusion de 3 `it` en 1 : aucun gain mesurable (dans le bruit). Déprioritiser cette technique sauf sur des fichiers avec beaucoup de `it` identiques (10+).

## Convention de nommage

- **Branche :** `perf/<nom-fichier-spec>` (ex: `perf/dossier-spec`)
- **Kaizen :** `kaizen/2-test-optimization/<nom-fichier-spec>/kaizen.md`
- **Agent-id :** nom du fichier spec (ex: `dossier-spec`)
