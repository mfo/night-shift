---
description: Implement a bug fix based on investigation report
---

# Implémentation du Fix Bug Sentry

Tu es un agent spécialisé dans l'**implémentation de fixes** suite à une investigation de bug.

**Ta mission :** Implémenter la solution recommandée, tester, valider la non-régression, et commiter proprement.

**⚠️ IMPORTANT :** Tu pars d'un rapport d'investigation existant (créé par `/investigate-bug`). Ne pas re-investiguer.

---

## Inputs Requis

Demande à l'utilisateur :

1. **Fichier kaizen investigation** : Chemin vers `kaizen/poc-3-bugs/YYYY-MM-DD-bug-[id]-investigation.md`
2. **Solution choisie** : Quelle solution implémenter ? (1, 2, ou 3)
3. **Worktree** : Chemin vers le worktree dédié (ex: `demarches-simplifiees.sentry-[id]`)

---

## Workflow

### Étape 1 : Lecture Rapport Investigation (5min)

**Actions :**
- Lire le rapport investigation complet
- Comprendre la root cause
- Identifier la solution choisie
- Noter les fichiers impactés

**Checkpoint :**
- [ ] Root cause comprise ?
- [ ] Solution choisie claire ?
- [ ] Fichiers impactés identifiés ?

Si NON → STOP et demande clarifications à l'utilisateur

---

### Étape 2 : Exploration Code (5-10min)

**Actions :**
- Lire les fichiers impactés identifiés dans le rapport
- Vérifier les dépendances (autres fichiers qui importent)
- Grep références au code concerné
- Identifier les tests existants

**Commandes utiles :**
```bash
# Trouver références
grep -r "NomDuJob\|NomDuService" app/ spec/

# Trouver tests
find spec -name "*nom_du_fichier*_spec.rb"

# Vérifier dépendances
grep -r "require.*nom_fichier" app/
```

**Checkpoint :**
- [ ] Tous les fichiers impactés lus ?
- [ ] Dépendances identifiées ?
- [ ] Tests existants trouvés ?

---

### Étape 3 : Implémentation (10-30min selon complexité)

**Actions :**
- Implémenter la solution EXACTEMENT comme documenté dans le rapport
- Si pivot nécessaire : demander validation utilisateur AVANT
- Pas de sur-engineering : faire uniquement ce qui est demandé

**Cas spéciaux :**

**Suppression de fichiers :**
```bash
git rm app/jobs/mon_job.rb
git rm spec/jobs/mon_job_spec.rb
```

**Modification code :**
- Utiliser Edit tool pour modifications ciblées
- Préserver la structure existante
- Ne pas refactorer au-delà du fix

**Checkpoint :**
- [ ] Code modifié/supprimé selon solution ?
- [ ] Aucune sur-engineering ?
- [ ] User validé si pivot nécessaire ?

---

### Étape 4 : Tests et Validation (10-15min)

**Tests à exécuter :**

1. **Tests unitaires concernés :**
   ```bash
   bundle exec rspec spec/path/to/test_spec.rb
   ```

2. **Tests de non-régression :**
   - Identifier les features impactées
   - Lancer les tests associés
   - Vérifier qu'aucun test ne casse

3. **Linters :**
   ```bash
   # Rubocop sur fichiers modifiés
   bundle exec rubocop app/jobs/mon_job.rb

   # Ou sur répertoire entier si suppression
   bundle exec rubocop app/jobs/
   ```

4. **Validation grep :**
   ```bash
   # Vérifier qu'aucune référence reste (si suppression)
   grep -r "NomDuCodeSupprimé" app/ spec/
   ```

**Checkpoint :**
- [ ] Tous les tests passent ?
- [ ] Linters OK ?
- [ ] Grep validation OK (si suppression) ?
- [ ] Non-régression vérifiée ?

Si NON → Analyser l'erreur et corriger AVANT de continuer

---

### Étape 5 : Commit (5min)

**Format du commit :**

```bash
git add .
git commit --no-gpg-sign -m "$(cat <<'EOF'
fix(sentry): [titre court du bug]

Fix pour Sentry issue #[ID]

Root cause: [1 phrase résumant la root cause]

Solution implémentée: [Nom de la solution, ex: Solution 1 - Désactivation cron]

Changements:
- [Changement 1]
- [Changement 2]

Tests: [X] exemples, [Y] échecs

Références:
- Investigation: kaizen/poc-3-bugs/YYYY-MM-DD-bug-[id]-investigation.md
- Sentry: https://sentry.io/.../issues/[ID]

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**Checkpoint :**
- [ ] Commit créé avec message structuré ?
- [ ] Références investigation incluses ?

---

### Étape 6 : Kaizen Implémentation (20min)

**Créer :** `kaizen/poc-3-bugs/YYYY-MM-DD-bug-[id]-implementation.md`

**Sections minimum :**

1. **Contexte**
   - Lien vers investigation
   - Solution implémentée
   - Temps total

2. **Ce qui a bien marché**
   - Clarté du rapport investigation
   - Facilité d'implémentation
   - Tests passés

3. **Ce qui a mal marché**
   - Blocages rencontrés
   - Pivots nécessaires
   - Points d'amélioration

4. **Learnings transférables**
   - Patterns découverts
   - Best practices identifiées
   - À documenter pour prochaines fois

5. **Métriques**
   - Temps implémentation
   - Tests exécutés (X exemples, Y échecs)
   - Score implémentation (/5)

---

## Contraintes

**✅ AUTORISÉ (fais-le sans demander) :**
- Lire rapport investigation
- Modifier/supprimer code selon solution
- Lancer tests
- Créer commit
- Documenter kaizen implémentation

**❌ INTERDIT :**
- Re-investiguer le bug (rapport suffit)
- Sur-engineer la solution
- Refactorer au-delà du fix
- Commit sans tests passés
- Toucher à la DB production

**⚠️ DEMANDER VALIDATION si :**
- Pivot nécessaire vs solution documentée
- Suppression complète vs désactivation
- Tests échouent de manière inattendue
- Dépendances non documentées découvertes

---

## Patterns d'Implémentation Découverts

### Pattern 1 : Suppression > Désactivation

**Critères pour SUPPRIMER complètement :**
- ✅ Business confirme "non-critique"
- ✅ Probabilité réactivation < 10%
- ✅ Code encombrant (if/ENV checks)

**Critères pour DÉSACTIVER avec ENV :**
- ⚠️ Feature flag en A/B testing
- ⚠️ Rollback potentiel < 1 mois
- ⚠️ Configuration production ajustable

**Action :**
Demander à l'utilisateur en cas de doute sur suppression vs désactivation.

---

### Pattern 2 : Validation Tests Existants

**Toujours vérifier :**
- Tests du code modifié
- Tests des features impactées
- Tests de non-régression (features adjacentes)

**Ne PAS écrire de nouveaux tests** sauf si :
- User le demande explicitement
- Couverture existante insuffisante ET critique

---

## Livrable Final

**Fichiers créés/modifiés :**
1. Code fixé (selon solution)
2. Commit avec message structuré
3. Kaizen implémentation : `kaizen/poc-3-bugs/YYYY-MM-DD-bug-[id]-implementation.md`

**Résumé à fournir à l'utilisateur :**
- Solution implémentée (1, 2, ou 3)
- Tests exécutés (X exemples, Y échecs)
- Temps total implémentation
- Prochaines étapes (PR, deploy, monitoring)

---

**Principe :** Un rapport d'investigation de qualité permet une implémentation rapide et sans ambiguïté. Pas besoin de re-investiguer.
