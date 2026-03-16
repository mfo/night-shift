# POC 4 : Bug Sentry Investigation - Setup

**Date :** 2026-03-09
**Objectif :** Valider que Claude peut investiguer et fixer un bug simple avec supervision minimale

---

## Setup

### Worktree Créé

```bash
cd ../demarche.numerique.gouv.fr
git worktree add -b poc-bug-fix ../demarche.numerique.gouv.fr-poc-bug main
```

**Localisation :** `/Users/mfo/dev/demarche.numerique.gouv.fr-poc-bug`
**Branche :** `poc-bug-fix`

### Choix du Bug

**Critères pour bug "agent-friendly" :**
- ✅ Stack trace claire et complète
- ✅ Occurrences > 10 (pattern répétitif)
- ✅ Catégorie simple : NoMethodError (nil check), N+1, validation, typo
- ✅ Reproductible facilement
- ❌ Pas de bug sécurité/auth/permissions
- ❌ Pas de logique métier ultra complexe
- ❌ Pas de bug critique (prod down)

**Exemples de bugs "agent-friendly" :**

**Type 1 : NoMethodError (nil check manquant)**
```
NoMethodError: undefined method `name' for nil:NilClass
app/views/dossiers/show.html.erb:42:in `block in _app_views_dossiers_show_html_erb'
```

**Type 2 : N+1 Query**
```
N+1 Query detected: SELECT * FROM users WHERE id = ?
Called 50 times from app/controllers/dossiers_controller.rb:28
```

**Type 3 : Validation Failed**
```
ActiveRecord::RecordInvalid: Validation failed: Email can't be blank
app/controllers/users_controller.rb:15:in `create'
```

### Bug Exemple pour POC

**Option A : Utiliser un vrai bug du backlog Sentry**
- Copier stack trace complète
- Copier contexte (user-agent, params, etc.)
- Copier fréquence d'occurrence

**Option B : Créer un bug fictif réaliste (si pas d'accès Sentry)**

```markdown
# Bug Example : NoMethodError sur dossier.user

**Error :** NoMethodError: undefined method `email' for nil:NilClass

**Stack Trace :**
```
app/views/dossiers/show.html.erb:42:in `block in _app_views_dossiers_show_html_erb___123456789'
app/controllers/dossiers_controller.rb:28:in `show'
```

**Contexte :**
- Occurrences : 23 fois sur les 7 derniers jours
- Impact : Utilisateurs instructeurs uniquement
- Fréquence : ~3 fois/jour
- Route : GET /dossiers/:id

**Params :**
```json
{
  "id": "12345",
  "controller": "dossiers",
  "action": "show"
}
```

**User Agent :** Mozilla/5.0 (Chrome...)

**Hypothèse :**
Dossiers sans user associé (user supprimé ?)
```

---

## Prompt Minimal pour Claude

```markdown
# Tâche : Investiguer et Fixer Bug Sentry

## Contexte
Tu es dans le worktree : /Users/mfo/dev/demarche.numerique.gouv.fr-poc-bug

Lis d'abord : .claude/context/essentials.md

## Objectif
Investiguer la root cause d'un bug, proposer un fix, écrire des tests

## Bug à Investiguer

[Copier le bug Sentry complet : stack trace, contexte, fréquence]

**Exemple :**

```
Error: NoMethodError: undefined method `email' for nil:NilClass

Stack Trace:
app/views/dossiers/show.html.erb:42
app/controllers/dossiers_controller.rb:28

Occurrences: 23 fois (7 jours)
Impact: Instructeurs uniquement
Route: GET /dossiers/:id
```

## Instructions

### Étape 1 : Analyse Stack Trace (20min)

1. Lis la stack trace et identifie :
   - **Fichier exact :** app/views/dossiers/show.html.erb
   - **Ligne exacte :** 42
   - **Erreur :** NoMethodError sur nil

2. Lis le fichier à la ligne indiquée :
   ```bash
   # Ouvre le fichier et regarde ligne 42
   ```

3. Comprends le contexte :
   - Quel objet est `nil` ? (ici : probablement `dossier.user`)
   - Pourquoi il serait `nil` ? (user supprimé ? orphelin ?)
   - C'est un edge case ou un cas fréquent ?

4. Vérifie le modèle :
   ```ruby
   # Dans app/models/dossier.rb
   belongs_to :user  # optional: true ?
   ```

### Étape 2 : Investigation & Root Cause (30min)

1. Confirme l'hypothèse en cherchant des dossiers sans user :
   ```bash
   bundle exec rails console
   > Dossier.where(user_id: nil).count
   # Si > 0 → hypothèse confirmée
   ```

2. Identifie l'origine :
   - Migration qui a créé des dossiers orphelins ?
   - Suppression de users sans cascade ?
   - Business logic qui permet user_id = nil ?

3. Décide du fix approprié :

   **Option A : Nil check (si user peut être nil légitimement)**
   ```ruby
   <%= dossier.user&.email || 'Utilisateur supprimé' %>
   ```

   **Option B : Validation (si user doit toujours exister)**
   ```ruby
   # Dans app/models/dossier.rb
   validates :user, presence: true
   ```

   **Option C : Nettoyage données + nil check**
   - Nettoyer les dossiers orphelins
   - Ajouter nil check pour éviter futur problèmes

### Étape 3 : Reproduire le Bug (30min)

1. Écris un test qui REPRODUIT le bug :
   ```ruby
   # spec/views/dossiers/show.html.erb_spec.rb (ou system spec)

   it "affiche la vue même si user est nil" do
     dossier = create(:dossier, user: nil)

     # Ce test doit ÉCHOUER actuellement (reproduit le bug)
     expect {
       render 'dossiers/show', dossier: dossier
     }.not_to raise_error
   end
   ```

2. Lance le test et vérifie qu'il ÉCHOUE :
   ```bash
   bundle exec rspec spec/views/dossiers/show.html.erb_spec.rb
   # Attendu : 1 example, 1 failure (NoMethodError)
   ```

### Étape 4 : Implémenter le Fix (30min)

1. Applique le fix choisi :

   **Si Option A (nil check) :**
   ```erb
   <!-- app/views/dossiers/show.html.erb ligne 42 -->
   <!-- AVANT -->
   <p>Contact: <%= dossier.user.email %></p>

   <!-- APRÈS -->
   <p>Contact: <%= dossier.user&.email || 'Utilisateur supprimé' %></p>
   ```

   **Si Option B (validation) :**
   ```ruby
   # app/models/dossier.rb
   validates :user, presence: true
   ```

2. Lance le test et vérifie qu'il PASSE maintenant :
   ```bash
   bundle exec rspec spec/views/dossiers/show.html.erb_spec.rb
   # Attendu : 1 example, 0 failures ✅
   ```

### Étape 5 : Vérification Non-Régression (30min)

1. Lance tous les tests liés :
   ```bash
   # Tests du modèle
   bundle exec rspec spec/models/dossier_spec.rb

   # Tests du controller
   bundle exec rspec spec/controllers/dossiers_controller_spec.rb

   # Tests system si applicable
   bundle exec rspec spec/system/instructeur/dossier_spec.rb
   ```

2. Vérifie qu'aucun test ne régresse

3. Si régressions → analyse et ajuste le fix

### Étape 6 : Commit (10min)

```bash
git add app/views/dossiers/show.html.erb spec/views/dossiers/show.html.erb_spec.rb

git commit -m "$(cat <<'EOF'
fix: Handle nil user in dossier view

Issue: NoMethodError when dossier.user is nil
Frequency: 23 occurrences over 7 days
Root cause: Some dossiers have no associated user (deleted users)

Solution: Added safe navigation operator (&.) with fallback text

Tests: Added spec to prevent regression

Fixes Sentry issue: [ID si applicable]

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Étape 7 : Rapport Investigation (20min)

Écris un rapport d'investigation détaillé (format ci-dessous)

## Contraintes IMPORTANTES

**✅ AUTORISÉ (fais-le sans demander) :**
- Lire stack trace
- Analyser le code
- Lancer console Rails pour investigation
- Écrire tests
- Implémenter fix
- Lancer tests
- Commit les changements

**❌ INTERDIT :**
- Fixer bugs touchant auth/permissions sans validation humaine
- Modifier logique métier complexe sans proposer options d'abord
- Commit si tests échouent
- Ignorer la root cause (fix symptôme sans comprendre)

**⚠️ SI PROBLÈME :**
- Bug touche auth/permissions → STOP et demande validation
- Root cause unclear → propose 2-3 hypothèses et demande
- Tests régressent → rollback et explique
- Tu bloques > 1h → arrête et explique où tu bloques

## Checkpoints Jidoka

**À 1h :**
- [ ] Root cause identifiée clairement ?
- [ ] Fix proposé fait sens ?
- Si NON → STOP et demande aide

**À 2h :**
- [ ] Tests reproduisent le bug ?
- [ ] Fix implémenté ?
- [ ] Test du fix passe ?
- Si NON → STOP et explique

**Avant commit :**
- [ ] Tests passent (nouveaux + existants) ?
- [ ] Aucune régression ?
- [ ] Commit message clair ?

## Format du Rapport Investigation

```markdown
## Rapport Investigation Bug Sentry

### 1. Bug Identifié

**Error :** NoMethodError: undefined method `email' for nil:NilClass

**Localisation :**
- Fichier : app/views/dossiers/show.html.erb
- Ligne : 42
- Méthode : show

**Fréquence :**
- Occurrences : 23 fois (7 jours)
- Impact : Instructeurs uniquement
- Criticité : MEDIUM (affichage cassé mais pas bloquant)

### 2. Root Cause Analysis

**Cause racine :**
Certains dossiers ont `user_id = nil` (utilisateurs supprimés)

**Pourquoi ça arrive :**
- Users peuvent être supprimés (RGPD)
- Association `belongs_to :user, optional: true` permet nil
- Vue assume que user existe toujours

**Données affectées :**
```ruby
Dossier.where(user_id: nil).count
# => 15 dossiers sans user
```

**5 Whys :**
1. Pourquoi l'erreur ? → user est nil
2. Pourquoi user nil ? → user_id est nil en DB
3. Pourquoi user_id nil ? → user a été supprimé
4. Pourquoi suppression casse ? → pas de cascade + vue assume présence
5. Pourquoi vue assume ? → business logic non documentée

### 3. Solution Implémentée

**Approche choisie :** Option A (nil check avec fallback)

**Justification :**
- User peut légitimement être nil (suppression RGPD)
- Validation `presence: true` casserait suppression users
- Nil check + fallback = solution défensive

**Code modifié :**
```diff
- <p>Contact: <%= dossier.user.email %></p>
+ <p>Contact: <%= dossier.user&.email || 'Utilisateur supprimé' %></p>
```

**Alternatives considérées :**
- Option B (validation) : Rejetée car empêcherait suppression users
- Option C (nettoyage données) : Trop invasif pour ce POC

### 4. Tests Ajoutés

**Test de régression :**
```ruby
# spec/views/dossiers/show.html.erb_spec.rb
it "affiche la vue même si user est nil" do
  dossier = create(:dossier, user: nil)
  expect {
    render 'dossiers/show', dossier: dossier
  }.not_to raise_error
  expect(rendered).to include('Utilisateur supprimé')
end
```

**Résultat :**
- Test reproduit le bug : ✅ (échouait avant fix)
- Test passe après fix : ✅
- Couvre le edge case : ✅

### 5. Vérification Non-Régression

**Tests lancés :**
```bash
bundle exec rspec spec/models/dossier_spec.rb
# => 42 examples, 0 failures ✅

bundle exec rspec spec/controllers/dossiers_controller_spec.rb
# => 28 examples, 0 failures ✅

bundle exec rspec spec/system/instructeur/dossier_spec.rb
# => 15 examples, 0 failures ✅
```

**Régression :** AUCUNE ✅

### 6. Impact & Recommandations

**Impact du fix :**
- Bug résolu : ✅
- 15 dossiers affichables à nouveau : ✅
- Prévention future : ✅ (test de régression)

**Recommandations :**
1. **Court terme :** Deploy ce fix (résout 23 erreurs/semaine)
2. **Moyen terme :** Audit autres vues avec `dossier.user` sans nil check
3. **Long terme :** Documenter business logic (user peut être nil)

**Pattern détecté :**
Ce bug pourrait exister ailleurs. Chercher :
```bash
grep -r "dossier.user\." app/views/
# Vérifier chaque occurrence pour nil safety
```

### 7. Résumé

**Status :** ✅ RÉSOLU

**Temps :** 2h15min
- Investigation : 50min
- Reproduction : 30min
- Fix : 30min
- Tests : 25min

**Commit :** `fix: Handle nil user in dossier view`

**Problèmes rencontrés :** AUCUN

**Learnings :**
- Pattern nil check + fallback est commun
- Tests de edge cases sont critiques
- Investigation 5 Whys aide à comprendre root cause
```

## Time Budget
**Total : 3h max**
- Analyse stack trace : 20min
- Investigation root cause : 30min
- Reproduction bug : 30min
- Implémentation fix : 30min
- Vérification non-régression : 30min
- Commit : 10min
- Rapport : 20min

Si tu dépasses 3h → arrête et dis pourquoi.

Bonne chance ! 🚀
```

---

## Critères de Succès POC

**Ce POC est réussi si :**
- [ ] Claude identifie correctement la root cause
- [ ] Test reproduit le bug avant fix
- [ ] Fix résout le bug (test passe)
- [ ] Aucune régression (tous tests passent)
- [ ] Temps < 3h
- [ ] Rapport investigation clair et actionnable
- [ ] Pas besoin d'intervenir (sauf checkpoint 1h si bloqué)

**Ce POC est partiellement réussi si :**
- [ ] Fix correct mais > 3h
- [ ] 1-2 questions de clarification sur business logic
- [ ] Rapport bon mais incomplet

**Ce POC échoue si :**
- [ ] Root cause incorrecte
- [ ] Fix ne résout pas le bug
- [ ] Régressions introduites
- [ ] Bloqué > 4h
- [ ] Nécessite supervision constante

---

## Notes

**Pourquoi ce POC est important :**
- Teste capacité d'analyse (pas juste coding)
- Valide workflow investigation structuré
- Plus proche de vrais bugs quotidiens

**Ce qu'on apprend :**
- Claude peut faire root cause analysis ?
- 5 Whys fonctionne en autonome ?
- Reproduction bug en test est naturelle ?

---

## Prochaines Étapes

**Une fois ce fichier créé :**
1. Créer worktree POC
2. Choisir un vrai bug Sentry OU créer bug fictif réaliste
3. Copier stack trace complète dans le prompt
4. Lancer Claude avec le prompt ci-dessus
5. Observer sans intervenir (checkpoint 1h si bloqué)
6. Noter le temps écoulé
7. Review le rapport investigation
8. Documenter dans `learnings/poc-4-bug-sentry-results.md`

---

*Setup créé le : 2026-03-09*
