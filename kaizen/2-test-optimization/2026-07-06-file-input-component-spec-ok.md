---
name: test-optimization-file-input-component-spec-ok
description: 41.8% gain on file_input_component_spec via T08 (let_it_be) — 2 bugs squashed, sub-agent bypassed
metadata:
  type: kaizen
  skill: test-optimization
  score: 6
status: traité
date_synth: 2026-07-08
---

# Test-optimization OK — file_input_component_spec (2026-07-06)

## Ce qui s'est passé

Le skill `test-optimization` a optimisé `spec/components/attachment/file_input_component_spec.rb` en mode auto. Résultat : **41.8% de gain** (médiane 2.80s → 1.63s), 22 exemples, 0 échecs, coverage maintenue (38.54% → 38.56%).

### Techniques appliquées

**T08 — let_it_be** : conversion de `types_de_champ_public`, `procedure`, `dossier` de `let` → `let_it_be` (read-only, jamais mutés).

### Techniques non retenues

| Technique | Raison |
|-----------|--------|
| T09 — aggregate_failures | Gain marginal < 0.5s après let_it_be ; les tests restants les plus lents sont dans des contextes avec procedure/dossier différents |
| T01 — create→build | Objets ont besoin d'être persistés (dossier référence procedure, logo attachment) |

### Bugs squattés

1. **Ordre de définition** : `let_it_be` évalue eager — `types_de_champ_public` doit précéder `procedure` (qui dépend de `types_de_champ_public`). Résolu en réordonnant les déclarations.
2. **Mutation leaking** : `let_it_be(:dossier)` partage le même objet `champ` entre tests ; `before { champ.errors.add(...) }` mute l'objet partagé. Résolu en forçant `dossier.champs.reload.first` par test.

## Bien passé

- **Signal detection rapide** : les 4 signaux (T01, T08, T09, T12) ont été identifiés en 1 tour.
- **let_it_be déjà partiel** : le scanner a détecté que `let_it_be` était déjà require dans `spec_helper.rb` mais jamais utilisé — bon diagnostic.
- **Rétablissement après échec sub-agent** : le prompt sub-agent était trop long pour deepseek-v4-flash. Au lieu de réessayer, l'agent est passé en mode direct — **décision correcte** qui a économisé des tokens.
- **Couverture maintenue** : 38.54% → 38.56%, vérifiée.
- **Gain significatif** : 41.8% sur un fichier de 207 lignes, c'est un bon ROI.

## Mal passé

- **Sub-agent overflow** : le prompt passait le contexte de deepseek-v4-flash (100k tokens). Le skill devrait soit (a) détecter la taille du fichier et choisir mode direct, soit (b) tronquer le prompt pour les petits modèles.
- **2 bugs de regression** : les deux bugs (ordre, mutation) ont coûté ~3 tours de debug. Le pattern `let_it_be` + mutation dans `before` est un faux pas connu qui devrait être documenté dans `patterns.md`.
- **T09/T01 non appliquées** : l'analyse post-let_it_be a conclu marginal — correct, mais le coût d'évaluation (~1 tour) était non nul. Une heuristique « si gain > 30% après 1 technique, skip les autres » pourrait économiser ce tour.

## Appris

1. **Mutation leaking pattern** : quand `let_it_be` crée des objets AR partagés, tout `before` qui mute ces objets (via `errors.add`, `update`, etc.) est dangereux. Solution : `reload` ou passer en `let` pour les objets mutés.
2. **Ordre des let_it_be** : contrairement à `let` (lazy), `let_it_be` est eager. Les dépendances entre fixtures doivent être ordonnées explicitement.
3. **Sub-agent bypass** : quand le prompt sub-agent est trop long (>80% du context window), mieux vaut appliquer directement que de retenter avec un prompt plus court (le temps de compression/retry n'en vaut pas la peine).

## Actions

1. **`patterns.md`** — Ajouter le pattern « Mutation leaking with let_it_be » : quand un `before` modifie un objet AR partagé par `let_it_be`, forcer un `reload` ou repasser en `let`.
2. **`patterns.md`** — Ajouter le pattern « let_it_be ordering » : documenter que `let_it_be` est eager et que les dépendances entre fixtures doivent être ordonnées.
3. **`SKILL.md`** — Ajouter une heuristique : si le fichier fait < 300 lines et le prompt sub-agent dépasse 80% du context window, passer en mode direct (pas de sub-agent).
4. **`SKILL.md`** — Ajouter une heuristique post-optimisation : si gain > 30% après la première technique appliquée, sauter l'évaluation des techniques restantes (gain marginal garanti).
