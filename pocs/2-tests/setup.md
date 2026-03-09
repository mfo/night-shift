# POC 2 : Optimisation Tests Lents - Setup

**Date :** 2026-03-09
**Objectif :** Valider que Claude peut optimiser des tests lents en mode fire-and-forget

---

## Setup

### Worktree Créé

```bash
cd ../demarche.numerique.gouv.fr
git worktree add -b poc-optimize-tests ../demarche.numerique.gouv.fr-poc-tests main
```

**Localisation :** `/Users/mfo/dev/demarche.numerique.gouv.fr-poc-tests`
**Branche :** `poc-optimize-tests`

### Identification Tests Lents

**Commande profiling :**
```bash
cd /Users/mfo/dev/demarche.numerique.gouv.fr-poc-tests
bundle exec rspec --profile 10
```

**Critères pour choisir un test "agent-friendly" :**
- ✅ Temps > 5 secondes
- ✅ Causes probables : factories lourdes, N+1, API calls, sleep
- ❌ Pas de tests avec complexité métier inhérente
- ❌ Pas de tests selenium ultra-complexes

**Exemples typiques de tests lents (à identifier) :**
- Tests system avec beaucoup de `create` (factory_bot)
- Tests avec appels API non stubés
- Tests avec `sleep` ou `wait_for`
- Tests avec N+1 queries

### Fichier Choisi (Exemple)

**Après profiling, choisir 1-2 tests parmi les plus lents**

**Format de la tâche :**
```markdown
# Tests identifiés (exemple)

**Test 1 :** spec/system/instructeur/dossier_spec.rb:42
- Temps actuel : 8.5s
- Cause probable : Factories lourdes (create users, dossiers, champs)

**Test 2 :** spec/models/dossier_spec.rb:156
- Temps actuel : 6.2s
- Cause probable : N+1 query sur avis
```

---

## Prompt Minimal pour Claude

```markdown
# Tâche : Optimiser Tests Lents

## Contexte
Tu es dans le worktree : /Users/mfo/dev/demarche.numerique.gouv.fr-poc-tests

Lis d'abord : .claude/context/essentials.md

## Objectif
Optimiser 1-2 tests lents (> 5s) pour réduire leur temps d'exécution de > 50%

## Tests à Optimiser

[Copier les tests identifiés par profiling]

**Exemple :**
- spec/system/instructeur/dossier_spec.rb:42 (8.5s)
- spec/models/dossier_spec.rb:156 (6.2s)

## Instructions

### Étape 1 : Profiling & Analyse (15min)

1. Lance profiling pour confirmer les temps :
   ```bash
   bundle exec rspec spec/path/to/file_spec.rb:42 --profile
   ```

2. Identifie la cause de la lenteur :
   - Factories : trop de `create` vs `build` ?
   - N+1 queries : manque `includes` ?
   - API calls : pas de `stub` ?
   - Sleep/wait : optimisables ?

3. Note le temps AVANT optimisation

### Étape 2 : Investigation (20min)

1. Lis le test et comprends ce qu'il teste

2. Identifie le setup minimal nécessaire :
   - Quels objets doivent être persistés (DB) ?
   - Quels objets peuvent être `build` (mémoire) ?

3. Identifie les queries exécutées :
   ```ruby
   # Ajoute dans test temporairement
   around do |example|
     queries = []
     ActiveSupport::Notifications.subscribe('sql.active_record') do |_, _, _, _, details|
       queries << details[:sql]
     end
     example.run
     puts "Queries: #{queries.count}"
     puts queries.join("\n")
   end
   ```

### Étape 3 : Optimisation (30-45min)

**Techniques à appliquer :**

**A. Factories : create → build**
```ruby
# AVANT (lent - écrit en DB)
let(:user) { create(:user) }
let(:dossier) { create(:dossier) }

# APRÈS (rapide - en mémoire)
let(:user) { build(:user) }
let(:dossier) { build(:dossier, user: user) }

# Note : utilise create UNIQUEMENT si DB persistence nécessaire
```

**B. Fix N+1 queries**
```ruby
# AVANT (N+1)
dossiers.each { |d| d.user.name }

# APRÈS (includes)
Dossier.includes(:user).each { |d| d.user.name }
```

**C. Stub external calls**
```ruby
# AVANT (appel API réel)
result = ExternalService.fetch(id)

# APRÈS (stub)
allow(ExternalService).to receive(:fetch).and_return(mock_data)
```

**D. Réduire setup inutile**
```ruby
# AVANT
before do
  create_list(:dossier, 10)  # Tous créés
end

# APRÈS (si seul 1 est testé)
before do
  create(:dossier)  # Juste ce qui est nécessaire
end
```

**E. Optimiser sleep/wait**
```ruby
# AVANT
sleep 2

# APRÈS (si Capybara)
expect(page).to have_content('Text', wait: 1)
```

### Étape 4 : Vérification (20min)

1. Lance le test optimisé et mesure le temps :
   ```bash
   bundle exec rspec spec/path/to/file_spec.rb:42 --profile
   ```

2. Vérifie que le test passe toujours :
   ```bash
   bundle exec rspec spec/path/to/file_spec.rb:42
   ```

3. Vérifie qu'il n'y a pas de régression (tests liés) :
   ```bash
   bundle exec rspec spec/path/to/file_spec.rb
   ```

4. Calcule le gain :
   ```
   Temps AVANT : 8.5s
   Temps APRÈS : 2.1s
   Gain : 75% (6.4s économisés)
   ```

### Étape 5 : Rapport (10min)

Écris un résumé (format ci-dessous)

## Contraintes IMPORTANTES

**✅ AUTORISÉ (fais-le sans demander) :**
- Profiler les tests (`rspec --profile`)
- Lire les tests
- Modifier setup (create → build, stub, includes)
- Lancer tests pour vérifier
- Commit les changements

**❌ INTERDIT :**
- Changer le comportement testé (le test doit tester la même chose)
- Skip des tests
- Retirer des assertions
- Modifier le code source (juste les tests)

**⚠️ SI PROBLÈME :**
- Test échoue après optimisation → rollback et explique pourquoi
- Gain < 30% → explique les limitations
- Tu bloques > 30min → arrête et explique où tu bloques

## Format du Rapport

```markdown
## Résumé Optimisation Tests Lents

**Tests optimisés :** [nombre]

### Test 1 : [nom du test]

**Localisation :** spec/path/to/file_spec.rb:42

**Temps AVANT :** 8.5s
**Temps APRÈS :** 2.1s
**Gain :** 75% (-6.4s)

**Causes identifiées :**
- Factories lourdes : 10 `create` inutiles
- N+1 query sur associations `avis`

**Optimisations appliquées :**
- Remplacé 8 `create` par `build`
- Ajouté `includes(:avis)` dans scope
- Stubé appel API externe

**Tests :**
- Test optimisé : ✅ PASS
- Tests liés (fichier complet) : ✅ PASS (X examples, 0 failures)

### Test 2 : [nom du test]

[Même format]

---

## Résultat Global

**Temps total économisé :** XXs par run de cette spec
**Impact annuel :** [estimation si run 100 fois/jour]

**Problèmes rencontrés :** [AUCUN / liste]

**Limites :**
- [Ce qui ne peut pas être optimisé davantage]

**Commit :**
git add spec/
git commit -m "Optimize slow tests: [nom fichiers]

Reduced execution time by XX% by:
- Replacing create with build for factories
- Adding includes to prevent N+1
- Stubbing external API calls

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"
```

## Time Budget
**Total : 60min max**
- Profiling/analyse : 15min
- Investigation : 20min
- Optimisation : 25min
- Vérification : 20min
- Rapport : 10min

Si tu dépasses 60min → arrête et dis pourquoi.

Bonne chance ! 🚀
```

---

## Critères de Succès POC

**Ce POC est réussi si :**
- [ ] Claude identifie correctement les causes de lenteur
- [ ] Optimisations appliquées sans changer comportement
- [ ] Tests passent après optimisation
- [ ] Gain > 50% sur temps d'exécution
- [ ] Temps < 60min
- [ ] Rapport clair avec métriques avant/après
- [ ] Pas besoin d'intervenir pendant l'exécution

**Ce POC est partiellement réussi si :**
- [ ] Optimisation correcte mais > 60min
- [ ] Gain 30-50% (acceptable)
- [ ] 1-2 questions de clarification nécessaires

**Ce POC échoue si :**
- [ ] Tests échouent après optimisation
- [ ] Comportement modifié
- [ ] Gain < 30%
- [ ] Bloqué > 1h
- [ ] Nécessite supervision constante

---

## Prochaines Étapes

**Une fois ce fichier créé :**
1. Créer worktree POC
2. Lancer profiling pour identifier tests lents
3. Copier 1-2 tests dans le prompt
4. Lancer Claude avec le prompt ci-dessus
5. Observer sans intervenir (sauf si bloqué > 30min)
6. Noter le temps écoulé
7. Noter les questions posées
8. Review le résultat
9. Documenter dans `learnings/poc-2-optimize-slow-tests-results.md`

---

*Setup créé le : 2026-03-09*
