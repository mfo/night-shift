---
name: test-optimization
description: "Optimize slow RSpec test file. Use when user says 'optimize tests', 'speed up specs', or provides a slow spec file."
allowed-tools:
  - Read
  - Glob
  - Grep
  - Edit
  - Bash(bundle exec:*)
  - Bash(DISABLE_SPRING=1 bundle exec:*)
  - Bash(kill:*)
  - Bash(pgrep:*)
  - Bash(spring stop)
  - Bash(.claude/skills/test-optimization/coverage.sh:*)
  - Bash(git -C:*)
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(git status)
  - Bash(git worktree:*)
  - Bash(git checkout -b:*)
  - Bash(bin/rails:*)
  - Bash(bundle install)
  - Bash(bundle check)
  - Bash(cat coverage/:*)
  - Bash(grep:*)
  - Agent
  - Write(pr-description.md)
  - Skill(pr-description)
---

# Test Optimization (Coordinator)

**Input :** chemin vers un fichier spec — `$ARGUMENTS` (ex: `spec/models/dossier_spec.rb`)
**Output :** commits granulaires + pr-description.md

**Architecture :** cet agent est un **coordinateur léger**. Il profile, détecte les signaux, puis délègue chaque technique à un **sous-agent isolé** qui reçoit uniquement ce dont il a besoin. Cela évite de saturer le contexte sur les gros fichiers.

---

## Étape 0 : Setup

```bash
bundle exec spring start
```

---

## Étape 1 : Profiler (baseline)

1. **Temps** : 1 warm-up + 3 runs (médiane) — **SANS** `COVERAGE=true`
   ```bash
   bundle exec spring rspec $SPEC_FILE
   ```
2. **Coverage** : 1 run via le script dédié
   ```bash
   .claude/skills/test-optimization/coverage.sh $SPEC_FILE
   ```

C'est la baseline. Si un run est rouge → marquer `flaky` et s'arrêter.

---

## Étape 2 : Détecter les signaux (scan léger)

**NE PAS lire le fichier spec entier.** Scanner les signaux par grep :

```bash
grep -c 'create(' $SPEC_FILE                    # T01, T04
grep -c 'let!' $SPEC_FILE                       # T10
grep -c 'let(:' $SPEC_FILE                      # T08 (let_it_be candidates)
grep -c 'sleep' $SPEC_FILE                      # S01
wc -l < $SPEC_FILE                              # T12 (split si > 1000)
grep -c 'aggregate_failures' $SPEC_FILE         # T09 déjà appliqué ?
```

Construire la liste des techniques à tenter (celles dont le signal est positif).

**Ordre recommandé :** T08 (let_it_be) → T10 (let!→let) → T04 (setup inutile) → T01 (create→build) → T09 (aggregate) → T06 (dupliqués) → T11 (factory_default) → T12 (split). Pour system specs, ajouter : S01 → S02 → S03.

---

## Étape 3 : Déléguer technique par technique

Pour chaque technique détectée, lancer un **sous-agent** via `Agent`. Le sous-agent reçoit un prompt auto-suffisant avec :

1. La technique (ID + description + signal + risque)
2. Le chemin du fichier spec
3. La baseline courante (temps + coverage)
4. Les règles et commandes

**Template prompt sous-agent :**

```
Tu es un agent d'optimisation de tests RSpec. Tu appliques UNE technique.

## Technique : [ID] — [nom]
[Description complète de la technique depuis patterns.md]
Signal de détection : [signal]
Risque : [risque]
Gain typique : [gain]

## Fichier cible
`[chemin spec]`

## Baseline courante
- Temps : [X]s (médiane 3 runs)
- Coverage : [Y]%

## Travail à faire

1. Lire le fichier spec (et le code source testé si nécessaire)
2. Appliquer la technique
3. Vérifier tests verts :
   ```
   bundle exec spring rspec [chemin]
   ```
4. Si du code source (app/) a été modifié OU des it/describe supprimés/fusionnés → vérifier coverage :
   ```
   .claude/skills/test-optimization/coverage.sh [chemin]
   ```
   Toute baisse = rollback immédiat.
5. Mesurer le gain (1 warm-up + 3 runs, médiane, SANS COVERAGE=true)
6. Si gain >= 5% ET >= 0.5s → commit :
   ```
   perf(tests): [technique] — [fichier_spec]

   - Temps avant : Xs → après : Ys (gain Z%)
   - [explication]
   ```
7. Si gain < seuil → rollback toutes les modifications

## Règles dures
- Ne jamais skip un test
- Ne jamais push
- Pas de perte de couverture
- Tests verts pour commit

## Répondre avec
- `applied` ou `skipped` ou `failed`
- Temps après (si applied)
- Coverage après (si applied)
- Ce qui a été changé (1-2 phrases)
```

**Après chaque sous-agent :**
- Si `applied` → mettre à jour la baseline (temps + coverage)
- Passer à la technique suivante avec la nouvelle baseline

---

## Étape 4 : Description PR

Quand toutes les techniques sont épuisées, écrire `pr-description.md` :

```markdown
---
title: "Tech: optimiser les tests de <fichier_spec>"
---

# Probleme

Tests lents dans `<fichier_spec>` — temps baseline : Xs (mediane locale, 3 runs).

# Solution

Skill [`/test-optimization`](https://github.com/mfo/night-shift/blob/main/.claude/skills/test-optimization/SKILL.md)

### Techniques appliquees

| Technique | Avant | Apres | Gain |
|-----------|-------|-------|------|
| <technique1> | Xs | Ys | -Z% |
| <technique2> | Ys | Ws | -Z% |

### Techniques tentees sans succes

| Technique | Raison |
|-----------|--------|
| ... | ... |

**Resultat final : Xs → Ys (gain total Z%)**

Coverage : X% → Y% (maintenue)

Generated with [Claude Code](https://claude.com/claude-code)
```

---

## Règles dures

- ❌ Ne jamais skip un test
- ❌ Ne jamais push
- ❌ Pas de perte de couverture
- ✅ Tests verts pour commit
- ⏱️ 20min max par fichier (kill switch)

## Pièges connus (retours kaizen)

### let_it_be sur ce projet

`let_it_be` est utilisable mais avec 3 contraintes :

1. **Modifiers indisponibles.** `reload:` et `refind:` ne fonctionnent pas — le `require 'test_prof/recipes/rspec/let_it_be'` est chargé avant Rails (`spec_helper.rb:25`). Donc `let_it_be` ne s'applique qu'aux blocs **read-only** (scopes, queries, méthodes pures). Les blocs qui mutent les objets → pollution inter-tests.

2. **Ordre de déclaration.** L'insertion est séquentielle : déclarer les dépendances avant les dépendants.

3. **FK validation Rails 7.2.** `check_all_foreign_keys_valid!` valide toutes les FK après chaque insertion. Si l'objet `let_it_be` persiste mais ses dépendances sont nettoyées → FK orpheline.

### etablissement requis par DossierOperationLog

Les transitions d'état créent un `DossierOperationLog` dont `serialize_subject` accède à `etablissement`. Si nil → erreur. Vérifier avant de supprimer un `let(:etablissement)`.

### aggregate_failures : efficacité liée au coût du setup

Gain marginal si setup léger. Gain majeur si setup avec transitions d'état (~1s chacune). Prioriser T09 quand le `before` fait des transitions.

### Smart quotes

L'outil Edit remplace parfois `'` par `'`/`'`. Utiliser `"` ou passer par Bash.

## Convention de nommage

- **Branche :** `perf/<nom-fichier-spec>`
