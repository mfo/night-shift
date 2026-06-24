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
  - Skill(dev-auto-login)
  - Skill(screenshot-gist)
  - Skill(create-pr)
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

Si la spec contient une section "Validation Visuelle", l'exécuter après le dernier commit.

**Pré-requis Playwright :** vérifier que le serveur MCP Playwright est disponible. Si absent, fallback sur des screenshots manuels via le navigateur (documenter dans la PR que la validation est manuelle).

1. **Trouver une démarche de test adaptée** via `find-procedure.sh` (query ActiveRecord libre)
2. **Se donner les droits** via `rails runner` (ajouter comme admin/instructeur sur la procédure)
3. **Lancer `dev-auto-login`** pour l'authentification localhost
4. **Capturer les screenshots** selon le scénario défini dans la spec (Playwright MCP)
5. **Comparer avec les maquettes UX** de l'issue source (si disponibles)
6. **Publier via `screenshot-gist`** pour inclusion dans la PR

### Pièges connus (issus de sessions réelles)
- **Super-admin** : auth séparée de dev-auto-login, nécessite reset password + login form
- **Données insuffisantes** : la démarche trouvée peut ne pas avoir de dossiers dans le bon état — utiliser `rails runner` pour transitionner/créer les données manquantes
- **Apostrophes Unicode** : les textes FR utilisent des apostrophes typographiques ('), pas ASCII (') — matcher les assertions en conséquence

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
  "screenshots": ["https://gist.github.com/..."],
  "branch": "feature/nom-feature"
}
```

---

**Commence par lire le plan d'implémentation, puis exécute commit par commit en vérifiant tests verts à chaque étape.**
