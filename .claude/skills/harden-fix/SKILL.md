---
name: harden-fix
description: Corriger une faille de sécurité qualifiée par /harden-audit — test rouge prouvant la faille, test vert la fixant, PR explicative
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Edit
  - Bash(bundle exec rspec:*)
  - Bash(bundle exec rubocop:*)
  - Bash(git add:*)
  - Bash(git commit:*)
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(git status)
  - Bash(git checkout -b:*)
  - Bash(gh pr create:*)
  - Bash(gh gist create:*)
  - Bash(gh auth setup-git:*)
  - Bash(git clone:*)
  - Bash(git -C /tmp/:*)
  - Bash(cp:*)
  - Bash(grep:*)
  - Skill(screenshot-gist)
  - Agent
---

# Harden Fix — Corriger une faille de sécurité

Tu es un agent spécialisé dans la **correction de failles de sécurité** avec une approche TDD rigoureuse.

**Ta mission :** Prendre un fichier d'audit produit par `/harden-audit`, écrire un test qui prouve la faille, la corriger, et produire une PR pédagogique.

---

## Documents de référence

1. **`checklist.md`** (dans ce dossier) — Checklist par étape, validation audit, TDD, PR
2. **`../harden-audit/patterns.md`** — Patterns validés (anti-pattern "fixer en sortie plutôt qu'en entrée", etc.)

---

## Input

**Fichier d'audit** : `$ARGUMENTS` (ex: `audits/2026-03-20-idor-dossier-audit.md`)

Ce fichier est produit par `/harden-audit` et contient :
- Classification (OWASP, CWE, DREAD)
- Steps to reproduce
- Fichiers impactés avec lignes
- Root cause identifiée
- Statut de reproduction locale

**Prérequis :**
- [ ] Fichier d'audit existe et a `status: qualified` ?  → ✅ Continuer
- [ ] Fichier d'audit absent ou pas de fichier ? → ❌ Suggérer `/harden-audit` d'abord
- [ ] Verdict = "accepter le risque" ? → ⚠️ Confirmer avec l'utilisateur qu'il veut quand même fixer

---

## Étape 1 : Gate d'entrée — Vérifier les prérequis

### 1a. Vérification du fichier d'audit

1. **Lire le fichier d'audit** fourni en argument (`$ARGUMENTS`)
2. **Vérifier les champs obligatoires du frontmatter** :
   - [ ] `status: qualified` ? → ✅ Continuer
   - [ ] `chain_verified: true` ? → Si `false` ou absent → ⚠️ Re-vérification obligatoire à l'étape 2b
   - [ ] `affected_files` listés ? → Si absent → les identifier soi-même
   - [ ] `confidence` renseigné ? → Si `low` → re-vérification obligatoire à l'étape 2b
   - [ ] `test_vector` renseigné ? → Facilite l'écriture du test RED

3. **Gates bloquants** :
   - [ ] Fichier d'audit **absent** ? → ❌ Voir mode fast-track ci-dessous
   - [ ] `status` ≠ `qualified` ? → ❌ Suggérer `/harden-audit` d'abord
   - [ ] `verdict: accepter le risque` ? → ⚠️ Confirmer avec l'utilisateur
   - [ ] `verdict: faux positif` ? → ❌ STOP — ne pas fixer un faux positif

4. **Extraire les informations clés** :
   - Type de faille (OWASP / CWE)
   - Score DREAD et verdict
   - Steps to reproduce / test_vector
   - Fichiers impactés et root cause
   - Statut reproduction

### 1b. Mode fast-track (sans fichier d'audit)

**Si `$ARGUMENTS` est vide ou ne pointe pas vers un fichier d'audit existant** :

Créer un **audit minimal inline** avant de continuer. Ne pas skipper l'audit — le minimum de traçabilité est obligatoire.

1. Demander à l'utilisateur : type de faille, endpoint, root cause suspectée
2. Créer `audits/YYYY-MM-DD-[slug]-audit.md` avec les champs minimaux :
   ```yaml
   title: [Titre court]
   source: interne
   date: YYYY-MM-DD
   owasp: [A01-A10]
   dread_score: [estimation rapide /15]
   verdict: [fix immédiat / sprint courant]
   status: qualified
   category: security
   confidence: low
   chain_verified: false
   test_vector: "[à remplir]"
   affected_files: []
   ```
3. Remplir les sections minimales : Contexte, Root cause, Fichiers impactés
4. Continuer avec l'étape 2 — la re-vérification est obligatoire (confidence: low)

---

## Étape 2 : Analyse du code vulnérable

En s'appuyant sur la section "Analyse technique" de l'audit :

1. **Lire les fichiers listés** dans l'audit (controllers, models, services, views)
2. **Confirmer la root cause** documentée dans l'audit
3. **Cartographier les points de correction** : où exactement intervenir

---

## Étape 2b : Re-vérification indépendante de la chaîne (OBLIGATOIRE si IDOR/BAC ou confidence ≠ high)

**Ne PAS faire confiance aveugle au fichier d'audit.** Avant de coder, re-tracer la chaîne soi-même.

### Quand cette étape est obligatoire :
- Faille de type **IDOR** ou **Broken Access Control** (A01) → toujours
- `confidence: low` ou `medium` dans l'audit → toujours
- `chain_verified: false` dans l'audit → toujours
- Tout autre type de faille → recommandé mais optionnel

### Comment re-vérifier :

1. **Tracer la chaîne d'appels** depuis le point d'entrée :
   ```
   Route → Controller action → before_action (héritées incluses !) → Service → Model → DB
   ```
   Lister chaque maillon avec `fichier:ligne`.

2. **Vérifier les protections à chaque niveau** :
   - Scope user (`current_user.dossiers.find(id)`) ?
   - Policy/authorize ?
   - before_action héritée du parent (`ApplicationController`) ?
   - default_scope ou STI sur le modèle ?
   - Contrainte DB (NOT NULL, CHECK) ?

3. **Verdict** :
   - **Faille toujours présente** (aucune protection à aucun niveau) → continuer vers l'étape 3
   - **Faille déjà protégée** à un niveau → **STOP — challenger l'audit**. Informer l'utilisateur : "L'audit dit X, mais le code montre une protection au niveau Y. Confirmer avant de coder ?"

---

## Étape 3 : Plan de commits

**❌ Ne jamais commencer à coder sans plan de commits validé.**

**Pattern TDD Sécurité (Red → Green → Harden) :**

```
Commit 1: test(security): add spec proving [vulnerability description]
  → Écrire le test qui PROUVE la faille (le test DOIT passer = la faille existe)
  → Le test démontre le comportement vulnérable actuel
  → Ex: "un utilisateur non autorisé PEUT accéder à la ressource"

Commit 2: fix(security): [description du fix]
  → Appliquer le correctif
  → Le test du commit 1 doit maintenant ÉCHOUER (la faille est bouchée)
  → Inverser l'assertion du test : le comportement vulnérable est désormais bloqué
  → Tous les tests passent (ancien + nouveau)

Commit 3: refactor(security): [durcissement optionnel] (optionnel)
  → Tests supplémentaires edge cases
  → Hardening complémentaire
```

**⚠️ Attention au sens des assertions :**
- **Commit 1 (test rouge)** : le test PROUVE que la faille existe. Ex: `expect(response).to have_http_status(:ok)` quand un user non autorisé accède à une ressource protégée → le test passe = la faille est réelle.
- **Commit 2 (test vert)** : après le fix, ce même scénario doit maintenant retourner une erreur. On met à jour l'assertion : `expect(response).to have_http_status(:unauthorized)` → le test passe = la faille est corrigée.

**Valider le plan avec l'utilisateur AVANT de coder.**

---

## Étape 4 : Commit 1 — Test prouvant la faille (RED)

1. **Écrire le test de sécurité** (en s'appuyant sur les STR de l'audit) :
   - Request spec (pour failles HTTP : IDOR, broken access control, injection)
   - Model spec (pour failles logiques : validation bypass, mass assignment)
   - System spec (pour failles UI : XSS, CSRF)

2. **Le test DOIT passer** (il prouve que la faille existe actuellement)

3. **Vérifier** :
   ```bash
   bundle exec rspec <fichier_spec>
   ```
   → Tous les tests passent, y compris le nouveau

4. **Si le fix est déjà écrit dans un nouveau fichier** (ex: validateur, service) :
   `git stash` ignore les fichiers untracked → utiliser `git stash -u` ou déplacer le fichier temporairement (`mv fichier /tmp/` → commit test → `mv /tmp/fichier .`).

5. **Commit** :
   ```bash
   git add <fichiers_test>
   git commit -m "test(security): add spec proving [description faille]"
   ```

---

## Étape 5 : Commit 2 — Fix + inversion assertion (GREEN)

1. **Appliquer le correctif** (le minimum nécessaire) :
   - Ajouter le check d'autorisation manquant
   - Ajouter la validation / sanitization
   - Corriger la configuration
   - etc.
   - **Si nouveau fichier** (validateur, service) : vérifier `config/initializers/inflections.rb` pour le casing des acronymes (IP, URL, API, SSRF, etc.) avant de nommer la classe.

2. **Mettre à jour l'assertion du test** pour refléter le comportement corrigé :
   - Avant fix : `expect(response).to have_http_status(:ok)` (faille prouvée)
   - Après fix : `expect(response).to redirect_to(root_path)` ou `have_http_status(:unauthorized)` (faille corrigée)

3. **Vérifier** :
   ```bash
   bundle exec rspec <fichier_spec>
   ```
   → Tous les tests passent

4. **Lancer les tests de non-régression** :
   ```bash
   bundle exec rspec <specs liées au controller/model impacté>
   ```
   → Aucune régression

5. **Commit** :
   ```bash
   git add <fichiers_modifiés>
   git commit -m "fix(security): [description du fix]"
   ```

---

## Étape 6 : Mettre à jour le fichier d'audit et l'index

Mettre à jour le frontmatter du fichier d'audit :

```yaml
status: fixed
fixed_date: YYYY-MM-DD
fix_pr: [URL de la PR]
```

**Mettre à jour `audits/INDEX.md`** (le créer s'il n'existe pas) :

```markdown
| Date | Slug | Status | DREAD | Category | Verdict |
|------|------|--------|-------|----------|---------|
| YYYY-MM-DD | [slug] | fixed | X/15 | security | [verdict] |
```

---

## Étape 7 : PR explicative

**Créer une PR avec une description pédagogique** destinée à l'équipe.

Reprendre les informations du fichier d'audit (analogie, STR, impact) pour construire la PR — ne pas tout réécrire, le travail a déjà été fait par `/harden-audit`.

```markdown
## Problème

[Type de faille] sur [endpoint/feature].

**Source :** [YesWeHack / audit / découverte interne]
**Criticité :** [Score DREAD /15] — [Critique/Important/Modéré/Faible]
**Audit :** `[chemin vers le fichier audit]`

### La faille en 30 secondes

[Reprendre l'analogie de l'audit]

### Steps to reproduce (avant ce fix)

[Reprendre les STR de l'audit]

## Solution

### Ce qui a été corrigé

- [Changement 1 — pourquoi]
- [Changement 2 — pourquoi]

### Preuve par les tests

- **Test rouge** (commit 1) : prouve que la faille existait — [description du scénario testé]
- **Test vert** (commit 2) : prouve que la faille est corrigée — [même scénario, assertion inversée]

### Avant / Après (optionnel — si la faille est démontrable visuellement)

Utiliser `/screenshot-gist` pour uploader les screenshots sur un gist.

#### 1. Setup — [contexte de la faille]
![setup](https://gist.githubusercontent.com/<user>/<gist-id>/raw/setup.png)

#### 2. Avant (faille) — [ce qui se passe avant le fix]
![faille](https://gist.githubusercontent.com/<user>/<gist-id>/raw/faille.png)

#### 3. Après (fix) — [ce qui se passe après le fix]
![fix](https://gist.githubusercontent.com/<user>/<gist-id>/raw/fix.png)

### Points d'attention pour la review

- [ ] Le fix ne casse pas [feature liée]
- [ ] Le test couvre bien le scénario d'exploitation
- [ ] Pas d'impact sur les utilisateurs légitimes

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

---

## Contraintes

**✅ AUTORISÉ :**
- Lire le fichier d'audit et le code
- Écrire des tests de sécurité
- Implémenter le fix après validation user
- Créer commits et PR
- Mettre à jour le statut du fichier d'audit

**❌ INTERDIT :**
- Tester sur un environnement de production
- Sur-engineer la solution (fix minimal)
- Commit sans tests passés
- Exposer des credentials ou tokens dans les tests
- Commencer sans fichier d'audit (rediriger vers `/harden-audit`)

**⚠️ DEMANDER VALIDATION si :**
- Le fix impacte une feature critique
- Plusieurs approches de fix possibles
- Tests échouent de manière inattendue
- L'audit semble incomplet ou obsolète

---

## Découper une grosse branche en PRs atomiques (worktree + cherry-pick)

**Quand :** Un audit a produit plusieurs failles fixées sur une même branche. L'équipe préfère 1 PR par faille pour faciliter la review.

**Méthode :**

1. Identifier les commits par faille sur la branche principale d'audit :
   ```bash
   git log --oneline main..<branche-audit>
   ```

2. Pour chaque faille, créer une branche isolée via worktree :
   ```bash
   git worktree add /tmp/fix-<slug> main
   ```

3. Cherry-pick les commits de la faille dans le worktree :
   ```bash
   git -C /tmp/fix-<slug> cherry-pick <hash-test> <hash-fix>
   ```

4. Créer la PR depuis le worktree :
   ```bash
   git -C /tmp/fix-<slug> push -u origin fix/<slug>
   ```

5. Nettoyer les worktrees après merge :
   ```bash
   git worktree remove /tmp/fix-<slug>
   ```

---

## Livrable

- Test prouvant la faille (commit 1)
- Fix + assertion inversée (commit 2)
- PR explicative avec preuve par les tests
- Fichier d'audit mis à jour (`status: fixed`)
- Aucune régression
