# Spec POC 2 — Optimisation des tests lents

**Date :** 2026-03-15
**Statut :** v4 — post-review 3 Amigos x4
**Projet cible :** demarches-simplifiees.fr

---

## Objectif

Construire un skill d'optimisation de tests suffisamment compétent pour le lancer en autonomie. On itère fichier par fichier, on documente via kaizen, on améliore le skill, on valide chaque PR.

On construit le **workflow**, pas un rapport.

---

## Architecture

```
  ┌─────────────┐
  │  Inventaire  │  slow-tests-inventory.md
  │  (au hasard) │  mis à jour avec avant/après/gain
  └──────┬──────┘
         │  1 fichier
         ▼
   ┌──────────┐
   │  Agent    │  worktree isolé, séquentiel
   │  spec X   │  timeout : 20min
   └────┬─────┘
        │  N commits (1 par technique)
        │  re-profiling entre chaque (nouvelle baseline)
        ▼
   ┌──────────┐
   │ kaizen X │  kaizen/2-test-optimization/<agent-id>/kaizen.md
   └────┬─────┘  1 kaizen par fichier
        │
        ▼
   ┌──────────┐
   │ /kaizen  │  quand l'humain décide
   │  synth   │
   └────┬─────┘
        │
        ▼
   ┌──────────┐
   │ Skill v+ │  amélioré, fichier suivant
   └──────────┘
```

---

## Décisions prises

### Exécution

- **Séquentiel** : 1 agent à la fois sur la machine (mesures fiables)
- **1 fichier par itération** : boucle de feedback la plus courte possible
- **Ordre au hasard** : la diversité des fichiers nourrit mieux le catalogue que d'attaquer les plus gros d'abord
- **Premières itérations supervisées** : l'humain observe en temps réel
- **Kill switch** : 20min par fichier (ajustable après les premières itérations)

### Isolation

- Chaque agent travaille dans un **worktree git isolé**
- Chaque worktree a sa propre **DB PostgreSQL** (hook `post-checkout`)
- **Jamais de push** en phase d'optimisation
- Branche par agent : `perf/<nom-fichier-spec>`

### Scope de l'agent

- Input : **un fichier spec** de l'inventaire CI (unit ou system)
- L'agent optimise le **fichier entier**, pas seulement les lignes identifiées comme lentes
- L'agent **re-profile en local** pour établir sa propre baseline (les temps CI ≠ local)
- L'agent peut **modifier le code source** si c'est la root cause de la lenteur
- `patterns.md` est en **lecture seule** pour l'agent — seule la synthèse l'enrichit

### Protocole de mesure

- **1 run de warm-up** (ignoré) puis **3 runs, prendre la médiane**
- Seuil de gain : **>= 5% ET >= 0.5s en absolu** (les gains marginaux × milliers de tests = impact brutal)
- Mesure du gain sur le **temps total du fichier**
- **Runs de temps SANS `COVERAGE=true`** — l'overhead SimpleCov fausse les mesures (5-15%)
- **Baseline coverage** : mesurée au début (`COVERAGE=true bundle exec rspec spec/path/to/file_spec.rb`), mise à jour après chaque commit
- **Vérification coverage** : 1 run `COVERAGE=true` après chaque technique (vérifie tests + coverage en un seul run). Toute baisse = rollback immédiat.
- **Si modification du code source** : lancer aussi les specs directement liées (ex: modif `app/models/dossier.rb` → lancer `spec/models/dossier_spec.rb`). La CI rattrapera le reste.

### Critère d'arrêt agent

L'agent parcourt les techniques du catalogue :
1. Tente une technique
2. Mesure le gain (1 warm-up + 3 runs, médiane) : **>= 5% ET >= 0.5s** → commit, **< seuil** → rollback, noter dans kaizen
3. **Après chaque commit, nouvelle baseline = dernière mesure**
4. Tente la technique suivante sur cette nouvelle baseline
5. Continue tant qu'il y a des techniques et des gains >= 5%
6. Quand toutes les techniques sont essayées → kaizen et stop

**Kill switch** : 20min par fichier. Si dépassé → terminer la technique en cours, rollback si non commitée, kaizen avec `status: echec`.

**Flaky** : si un run de baseline est rouge → marquer le fichier comme `flaky` dans l'inventaire, kaizen minimal, fichier suivant.

### Critère d'arrêt global

On s'arrête quand on a essayé toutes les techniques sur tous les fichiers de l'inventaire.

### Règles dures

- ❌ Ne jamais skip un test
- ❌ Ne jamais push
- ❌ **Pas de perte de couverture** : supprimer du code dupliqué qui teste le même comportement = OK. Supprimer du code qui couvre un cas unique = interdit.
- ✅ Tests verts à la fin pour commit

### Guidelines indicatives

Les agents sont des **explorateurs** et des **collaborateurs** :
- Peut modifier le code source
- Peut supprimer des assertions, des `it`/`describe` dupliqués
- Peut réorganiser le setup
- Peut appliquer n'importe quelle technique, même hors catalogue
- **Autonome** dans le périmètre des permissions accordées — il fonce
- **Collaboratif** : s'il a besoin de quelque chose (tooling, MCP, conseil), il demande une fois. On est une équipe.
- Un blocage = une incapacité à avancer sans l'humain. Le noter dans le kaizen.

### Commits

- **Granulaires** : 1 commit par technique appliquée
- **Re-profiling entre chaque** : la nouvelle baseline = dernière mesure
- Format :
  ```
  perf(tests): [technique] — fichier_spec.rb

  - Temps avant : Xs → après : Ys (gain Z%)
  - [explication de ce qui a été changé et pourquoi]
  ```

### Kaizen

- **1 kaizen par fichier** dans `kaizen/2-test-optimization/<agent-id>/kaizen.md`
- Agent-id = nom du fichier spec (ex: `dossier-spec`)
- Template : `.claude/skills/test-optimization/template.md`
- **Kaizen toujours** — même en cas d'échec (`status: echec`)
- **Auto-rempli** par l'agent, question à l'humain si besoin de collaborer
- Si on relance sur le même fichier → le kaizen est écrasé

#### Champs obligatoires du kaizen

| Champ | Type | Description |
|---|---|---|
| `agent-id` | frontmatter | Nom du fichier spec |
| `spec-file` | frontmatter | Chemin complet |
| `status` | frontmatter | `succes` (≥1 commit), `echec` (aucune technique viable), ou `flaky` (baseline rouge) |
| Temps avant / après | métriques | Baseline locale (médiane 3 runs) |
| Coverage avant / après | métriques | Via `COVERAGE=true`, doit être >= avant |
| Technique(s) appliquée(s) | checklist | Depuis `patterns.md` |
| Technique(s) tentées sans succès | structuré | Technique + raison |
| Piège(s) rencontré(s) | structuré | Cause + fix |
| Blocages | liste plate | Ce qui a empêché d'avancer |
| Actions suggérées pour la synthèse | checklist | Propositions pour améliorer le skill |

### Synthèse

- Mode ajouté au **skill kaizen existant** (`/kaizen synth`)
- Déclenchée **quand l'humain décide** (pas après chaque fichier)
- Lit tous les kaizen de `kaizen/2-test-optimization/*/kaizen.md`
- Session **interactive** : itère sur les fichiers, compare avec le skill, propose des modifications
- **Rien n'est écrit sans validation** de l'utilisateur
- Propose :
  - Améliorations au skill `test-optimization`
  - Nouvelles techniques pour `.claude/skills/test-optimization/patterns.md`
  - Blocages récurrents à résoudre

### Catalogue de techniques

- Fichier : `.claude/skills/test-optimization/patterns.md`
- **Lecture seule** pour les agents
- Enrichi uniquement via `/kaizen synth` après validation humaine
- Catalogué par une équipe de 5 experts (T01-T11 par fichier + G01-G08 globales) — voir le fichier pour le détail

### Suivi du progrès

- `slow-tests-inventory.md` est mis à jour avec les colonnes **avant / après / gain / statut** au fur et à mesure
- Colonne **Statut** : vide = à traiter, `succes`, `echec`, `flaky` — évite de boucler sur les fichiers déjà traités
- C'est le tableau de bord naturel du POC

---

## Inventaire

**Source :** CI GitHub Actions du 2026-03-15
**Fichier :** `pocs/2-test-optimization/slow-tests-inventory.md`

| Catégorie | Fichiers | Tests lents | Temps cumulé |
|---|---|---|---|
| Unit tests | 37 | 68 | ~82s |
| System tests | 15 | 40 | ~174s |
| **Total** | **52** | **108** | **~256s** |

---

## Boucle

```
1. Choisir 1 fichier spec au hasard dans l'inventaire
2. Lancer l'agent dans un worktree isolé (timeout 20min)
3. L'agent : profiler → explorer techniques → commit par technique → kaizen
4. Mettre à jour slow-tests-inventory.md (avant/après/gain)
5. Quand l'humain décide : /kaizen synth → proposer améliorations
6. Valider → skill amélioré → PR si pertinent
7. Fichier suivant
```

**Les premières itérations sont supervisées** — l'humain observe en temps réel.

---

## Fichiers du POC

| Fichier | Rôle |
|---|---|
| `pocs/2-test-optimization/spec.md` | Ce fichier — spec complète |
| `pocs/2-test-optimization/setup.md` | Setup (worktree, DB, prérequis) |
| `pocs/2-test-optimization/slow-tests-inventory.md` | Inventaire + suivi avant/après/gain |
| `.claude/skills/test-optimization/SKILL.md` | Skill agent |
| `.claude/skills/test-optimization/patterns.md` | Catalogue des techniques communes (lecture seule) |
| `.claude/skills/test-optimization/patterns-system.md` | Catalogue des techniques system specs (lecture seule) |
| `.claude/skills/test-optimization/template.md` | Template kaizen structuré |
| `.claude/skills/kaizen/SKILL.md` | Skill kaizen (modes write + synth) |

---

## Questions ouvertes

Aucune.
