---
name: feature-implementation
description: "Execute commit-by-commit implementation (Stage 2). Use when user has a validated plan and wants to start coding."
allowed-tools:
  - Read
  - Glob
  - Grep
  - Edit
  - Write
  - Bash(bundle exec rspec:*)
  - Bash(bundle exec rubocop:*)
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(git status)
  - Bash(git push:*)
  - Bash(bin/rails runner:*)
  - Bash(bundle exec rails runner:*)
  - Bash(.claude/skills/feature-spec/find-procedure.sh:*)
  - Bash(ls:*)
  - Skill(dev-auto-login)
  - Skill(screenshot-gist)
  - Skill(create-pr)
  - Agent
---

# Implémentation Feature Commit par Commit (Stage 2)

Tu es un agent spécialisé dans l'**exécution de plans d'implémentation** commit par commit.

**Ta mission :** Exécuter le plan d'implémentation atomique avec tests verts à chaque étape.

## Documents de Référence

**Avant de commencer, lis :**
1. **`checklist.md`** — Checklist pré-commit, patterns critiques, checkpoints, pièges
2. **`patterns.md`** — 10 patterns validés (score 8-10/10) avec exemples

## Avant de commencer

**Vérifie :**
- [ ] Plan d'implémentation validé (Stage 1 terminée) ? → sinon retour Stage 1
- [ ] Tests actuels passent ? → sinon fixer d'abord

**Auto-découverte :** chercher le plan via `Glob("specs/*-implementation-plan.md")` — prendre le plus récent.
**Demande au user :** confirmer le plan trouvé, branche git, contraintes spécifiques.

---

## Étape 0 : Plan de Commits (OBLIGATOIRE AVANT TOUT CODE)

1. Chercher dans la spec/plan une section "Plan de commits" ou "Commits"
2. Si absente, proposer un découpage : `DB → model+specs → controller+specs → views → cleanup`
3. **Valider le plan avec le user AVANT de coder**
4. **Exécuter séquentiellement** en vérifiant tests verts à chaque commit

---

## Fast-path : Tâches Simples (< 5 commits)

Pour les tâches avec ≤ 5 fichiers et un plan évident :
1. Lister les commits (étape 0)
2. Exécuter séquentiellement, tests verts à chaque commit
3. Rubocop clean à la fin

Pas besoin de : checkpoint mi-phase, métriques détaillées, phases numérotées 1-7.

---

## Checkpoint Migrations vs Spec

**Avant de committer une migration :**
- [ ] Toutes les migrations listées dans la spec sont créées ?
- [ ] Strong Migrations : add constraint validate: false + validate constraint = **2 fichiers**

---

## RÈGLE ABSOLUE : Tests Verts à Chaque Commit

Chaque commit DOIT avoir tests passants. Interleave code + specs (même commit).

**Exception :** Breaking change atomique documenté — commit message DOIT contenir :
```
⚠️ TESTS BROKEN: [raison]
Fix in commits X-Y (N call-sites to update)
```

---

## Checklist Pré-Commit (POUR CHAQUE COMMIT)

- [ ] **Code compile ?**
- [ ] **Tests passent ?** — Si NON → documenter avec `⚠️ TESTS BROKEN`
- [ ] **Rubocop propre ?**
- [ ] **Specs mises à jour ?** — Si code change → specs aussi (même commit)
- [ ] **Plan à jour ?** — Marquer le commit comme fait dans le fichier plan

---

## Patterns Critiques

Voir `checklist.md` §Patterns Critiques et `patterns.md` pour le détail.

Résumé :
1. **State Checks Explicites** — `.state&.in?([...])` au lieu de boolean combinations
2. **Pas de Memoization Inappropriée** — recalculer dans actions modifiant état DB
3. **Self-Documenting Variables** — si nesting > 2 niveaux
4. **Tests Isolation** — setup context pour before_actions
5. **Validation Uniqueness** — cohérence validation Rails ↔ Index DB (piège SQLite/PostgreSQL)

### Checkpoint Validation Uniqueness (piège réel)

Quand tu ajoutes `validates :field, uniqueness: { scope: [...] }` :
1. Chercher index unique correspondant dans `db/migrate/` et `db/schema.rb`
2. Vérifier que scope et index couvrent les mêmes colonnes
3. Si incohérence → migration pour corriger

Tests passent en SQLite permissive, prod crashe en PostgreSQL strict.

### Sécurité (pré-commit)

- [ ] **Strong params** couvrent tous les champs du formulaire ?
- [ ] **Inputs sanitizés** ? (champs libres = `sanitize`, pas de `html_safe` sur user input)
- [ ] **CSRF** token sur les forms / `protect_from_forgery` sur les controllers non-API ?

---

## Checkpoint Mi-Phase (Après ~50% commits)

- [ ] Tests verts maintenus ? (0 failures)
- [ ] Breaking changes documentés en commit messages ?
- [ ] Patterns critiques appliqués ?
- [ ] Rubocop propre ?
- [ ] Aucun blocage > 30min ? → sinon STOP et demander aide user

---

## Validation Visuelle (si changement d'interface)

Exécuter la validation visuelle **à chaque checkpoint** défini dans le plan (pas seulement en fin d'implémentation). Les checkpoints sont dans `visual_validation.checkpoints` du JSON du plan.

**Pré-requis Playwright :** vérifier que le serveur MCP Playwright est disponible. Si absent, fallback sur des screenshots manuels via le navigateur (documenter dans la PR que la validation est manuelle).

### Convention de nommage

**Baselines** (maquettes UX de référence) dans `specs/assets/YYYY-MM-DD-[nom]/` :
```
ux-scenario-N-description.png
```

**Captures** Playwright dans `specs/assets/YYYY-MM-DD-[nom]/captures/` :
```
capture-scenario-N-description.png
```

Le **`scenario-N`** est le lien entre baseline et capture.

### Pipeline : visual-verify → visual-compare → correction

La validation visuelle utilise deux agents en séquence :

#### Étape 1 : Préparation (une seule fois)

1. **Charger les baselines** : `ls specs/assets/YYYY-MM-DD-[nom]/ux-scenario-*.png`
2. **Trouver une démarche de test adaptée** via `find-procedure.sh` (query ActiveRecord libre)
3. **Se donner les droits** via `rails runner` (ajouter comme admin/instructeur sur la procédure)
4. **Lancer `dev-auto-login`** pour l'authentification localhost

#### Étape 2 : Capture (agent `visual-verify`)

Déléguer la capture à l'agent `visual-verify` — ne JAMAIS appeler `mcp__playwright__*` directement (base64 pollue le contexte).

```
Agent(subagent_type: "visual-verify", prompt: "
  port: $PORT,
  urls: ['/instructeurs/procedures/X/dossiers/Y/suivi-et-decision'],
  selector: 'body',
  output_dir: 'specs/assets/YYYY-MM-DD-nom/captures/',
  prefix: 'capture-scenario-N'
")
```

#### Étape 3 : Comparaison (agent `visual-compare`)

Pour CHAQUE paire baseline/capture, lancer l'agent `visual-compare` :

```
Agent(subagent_type: "visual-compare", prompt: "
  baseline: specs/assets/YYYY-MM-DD-nom/ux-scenario-N-description.png
  capture: specs/assets/YYYY-MM-DD-nom/captures/capture-scenario-N-description.png
  context: description de ce qu'on compare
")
```

L'agent compare sur 6 axes systématiques :
1. **Éléments en trop** — texte/titre/bloc présent dans la capture mais absent de la maquette
2. **Contenu manquant** — texte/donnée présent dans la maquette mais absent de la capture
3. **Layout / dimensions** — largeur des blocs, débordements, containers
4. **Alignement** — éléments inline vs empilés, position relative
5. **Typographie / couleur** — couleur du texte, gras/normal, taille
6. **Espacement** — marges et padding entre sections

Il retourne un JSON structuré :
```json
{
  "status": "pass | fail",
  "findings": [{"axis": "...", "severity": "bloquant | important | mineur", "element": "...", "recommendation": "..."}],
  "summary": "N bloquants, N importants, N mineurs"
}
```

#### Étape 4 : Correction (boucle)

- **Si `status: "pass"`** → validation terminée, passer à la suite
- **Si `status: "fail"`** → pour chaque finding bloquant ou important :
  1. Corriger le code (vue, CSS, contrôleur, partial)
  2. Vérifier que les tests passent toujours
  3. Committer le fix : `fix(visual): description du problème`
  4. **Relancer le cycle** (Étape 2 → Étape 3) pour vérifier que le fix résout l'écart
  5. Maximum 3 itérations — au-delà, signaler au user pour arbitrage UX

**⚠️ RÈGLE CRITIQUE :** Ne JAMAIS conclure "ça match" sans avoir lancé `visual-compare`. La comparaison humaine à l'oeil est biaisée — l'agent compare systématiquement sur 6 axes et détecte les écarts subtils (container trop étroit, sous-titre redondant, couleur de texte).

### Pièges connus (issus de sessions réelles)
- **Super-admin** : auth séparée de dev-auto-login, nécessite reset password + login form
- **Données insuffisantes** : la démarche trouvée peut ne pas avoir de dossiers dans le bon état — utiliser `rails runner` pour transitionner/créer les données manquantes
- **Apostrophes Unicode** : les textes FR utilisent des apostrophes typographiques ('), pas ASCII (') — matcher les assertions en conséquence
- **Container CSS** : `container` (Bootstrap) ≠ `fr-container` (DSFR) — vérifier que le wrapper correspond au design system utilisé par le reste de la page
- **Sous-titres redondants** : quand du contenu existant (partials) est intégré dans un accordéon, les `.tab-title` deviennent redondants avec le titre de l'accordéon — les supprimer ou les rendre conditionnels
- **Données partielles** : un partial peut filtrer (ex: `manual` assignments seulement) alors que la maquette montre toutes les données (auto + manual) — vérifier le scope des queries

---

## Checklist Fin Stage 2

- [ ] Tous commits exécutés selon plan (comparer plan vs. réels)
- [ ] Suite complète tests passe (0 failures)
- [ ] Rubocop clean (0 offenses)
- [ ] Coverage ≥ 80%
- [ ] Breaking changes en blocs (merge safe)
- [ ] Feature implémentée complètement (acceptance criteria validées)
- [ ] Validation visuelle effectuée (si applicable)
- [ ] Prêt pour Stage 3 (Review & Cleanup) ?

---

## Handoff Stage 3

Quand la checklist ci-dessus est complète :
1. **Lancer `/feature-review`** (review-3-amigos) avec le diff de la branche
2. Si une **Issue Source** est dans la spec → la passer pour activer le **mode adversarial**
3. Après review validée → **lancer `/create-pr`** avec les screenshots capturés

---

## Note : Screenshots ambigus

Si le user demande des "captures" sans préciser → clarifier : screenshots Capybara (specs système) vs screenshots manuels (navigateur) vs screenshots Playwright (MCP).

---

## Output Structuré

Terminer le skill par un bloc JSON dans un code fence. Le harness valide la présence des champs requis.

```json
{
  "status": "complete | partial",
  "commits_executed": 12,
  "tests_pass": true,
  "rubocop_clean": true,
  "visual_validation": {
    "baseline_path": "specs/assets/YYYY-MM-DD-nom/",
    "captures_path": "specs/assets/YYYY-MM-DD-nom/captures/",
    "screenshots": ["https://gist.github.com/..."],
    "comparison": "pass | fail | partial"
  },
  "branch": "feature/nom-feature"
}
```

- `visual_validation.baseline_path` : repris du JSON de feature-plan. Contient les maquettes UX de référence.
- `visual_validation.captures_path` : screenshots capturés pendant l'implémentation, nommés pour correspondre aux scénarios de la spec.
- `visual_validation.comparison` : résultat de la comparaison visuelle baseline vs captures.

---

**Commence par lire le plan d'implémentation, puis exécute commit par commit en vérifiant tests verts à chaque étape.**
