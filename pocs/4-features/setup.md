# POC 5 : Feature Simple (GitHub Issue) - Setup

**Date :** 2026-03-09
**Objectif :** Valider que Claude peut implémenter une feature simple end-to-end en mode fire-and-forget

---

## Setup

### Worktree Créé

```bash
cd ../demarche.numerique.gouv.fr
git worktree add -b poc-simple-feature ../demarche.numerique.gouv.fr-poc-feature main
```

**Localisation :** `/Users/mfo/dev/demarche.numerique.gouv.fr-poc-feature`
**Branche :** `poc-simple-feature`

### Choix de la Feature

**Critères pour feature "agent-friendly" :**
- ✅ Spec fonctionnelle claire et détaillée
- ✅ Impact limité (< 3 fichiers modifiés)
- ✅ Acceptance criteria explicites
- ✅ Pas de migration DB complexe
- ✅ Pas de décision d'architecture majeure
- ❌ Pas d'API publique/GraphQL breaking change
- ❌ Pas de nouvelle entité métier complexe

**Exemples de features "agent-friendly" :**

**Type 1 : Ajout de filtre dans liste**
```markdown
Feature: Ajouter filtre "En retard" sur liste dossiers instructeur

Acceptance Criteria:
- [ ] Nouveau bouton "Dossiers en retard" dans toolbar
- [ ] Click → affiche dossiers avec date_limite < aujourd'hui
- [ ] Count visible (badge avec nombre)
- [ ] URL reflète le filtre (?filter=late)
- [ ] Tests system passent
```

**Type 2 : Export CSV**
```markdown
Feature: Export CSV des dossiers filtrés

Acceptance Criteria:
- [ ] Bouton "Exporter CSV" visible quand dossiers affichés
- [ ] Click → télécharge CSV avec colonnes : numéro, état, date dépôt
- [ ] Respecte les filtres actifs
- [ ] Tests controller passent
```

**Type 3 : Amélioration UX**
```markdown
Feature: Afficher tooltip sur statut dossier

Acceptance Criteria:
- [ ] Hover sur badge statut → tooltip explicatif
- [ ] Texte tooltip selon statut (en_construction, en_instruction, etc.)
- [ ] ARIA accessible (aria-label)
- [ ] Tests accessibilité passent
```

### Feature Exemple pour POC

**Feature Choisie : Filtre "En retard" sur dossiers instructeur**

```markdown
# Feature : Filtre "Dossiers en retard"

## Contexte
Les instructeurs veulent voir rapidement les dossiers en retard (date limite dépassée)

## User Story
En tant qu'instructeur,
Je veux filtrer les dossiers en retard,
Afin de les traiter en priorité.

## Spec Fonctionnelle

### UI
- Ajouter bouton "En retard" dans la barre de filtres
- Localisation : à côté des filtres "En construction", "En instruction"
- Badge avec count (nombre de dossiers en retard)
- Style : fr-badge fr-badge--error (DSFR)

### Logique
- Dossiers "en retard" = `date_limite < Date.today AND état IN ['en_instruction']`
- Exclus : dossiers archivés, acceptés, refusés
- Inclus : dossiers en_instruction uniquement

### Comportement
- Click sur "En retard" → URL change (?filter=late)
- Reload page avec filtre → filtre reste actif
- Count se met à jour dynamiquement

### Technique
- Scope dans model Dossier : `scope :late`
- Controller action : filtrer si params[:filter] == 'late'
- View : bouton conditionnel si instructeur
- Tests : system spec + model spec

## Acceptance Criteria

**Must Have :**
- [ ] Scope `Dossier.late` retourne dossiers avec date_limite < today
- [ ] Bouton "En retard (X)" visible pour instructeurs
- [ ] Click → affiche uniquement dossiers en retard
- [ ] URL reflète filtre (?filter=late)
- [ ] Count badge correct
- [ ] RGAA 4 : aria-label sur bouton
- [ ] Tests system passent
- [ ] Tests model passent

**Nice to Have (hors POC) :**
- [ ] Animation transition
- [ ] Persistence filtre en session

## Contraintes

**Sécurité :**
- Accessible instructeurs uniquement (policy Pundit)
- Pas de bypass authorization

**Accessibilité (RGAA 4) :**
- aria-label="Filtrer les dossiers en retard"
- Contraste couleurs suffisant
- Focus visible au clavier

**Performance :**
- Scope SQL optimisé (index sur date_limite)
- Pas de N+1 (includes si nécessaire)

**Tests :**
- Coverage ≥ 80%
- Tests system pour UI
- Tests model pour scope

## Fichiers Impactés (Estimation)

1. `app/models/dossier.rb` : scope late
2. `app/controllers/instructeur/dossiers_controller.rb` : filtre params
3. `app/views/instructeur/dossiers/index.html.erb` : bouton filtre
4. `spec/models/dossier_spec.rb` : tests scope
5. `spec/system/instructeur/dossier_spec.rb` : tests UI

**Total :** ~5 fichiers (< seuil de 3 → borderline, acceptable pour POC)
```

---

## Prompt Minimal pour Claude

```markdown
# Tâche : Implémenter Feature Simple (GitHub Issue)

## Contexte
Tu es dans le worktree : /Users/mfo/dev/demarche.numerique.gouv.fr-poc-feature

Lis d'abord : .claude/context/essentials.md

## Objectif
Implémenter une feature simple end-to-end avec approche TDD

## Feature à Implémenter

[Copier la spec fonctionnelle complète ci-dessus]

## Instructions

### Étape 1 : Compréhension & Plan (30min)

1. Lis la spec fonctionnelle complète

2. Analyse l'impact :
   - Quels fichiers modifier ? (lister)
   - Quels patterns utiliser ? (scope, controller filter, view button)
   - Quelles contraintes ? (RGAA, sécurité, perf)

3. Identifie les tests existants à lire :
   ```bash
   # Tests similaires pour s'inspirer
   grep -r "filter" spec/system/instructeur/
   grep -r "scope.*where" spec/models/dossier_spec.rb
   ```

4. Plan d'implémentation (ordre TDD) :
   - Tests model (scope) → Implémentation scope
   - Tests controller (filter) → Implémentation controller
   - Tests system (UI) → Implémentation view

### Étape 2 : Tests Model d'abord (30min)

1. Écris test pour scope `Dossier.late` :
   ```ruby
   # spec/models/dossier_spec.rb

   describe '.late' do
     context 'avec dossiers en retard' do
       let!(:dossier_late) { create(:dossier, date_limite: 2.days.ago, state: :en_instruction) }
       let!(:dossier_on_time) { create(:dossier, date_limite: 2.days.from_now, state: :en_instruction) }
       let!(:dossier_archived) { create(:dossier, date_limite: 2.days.ago, state: :accepte) }

       it 'retourne uniquement les dossiers en retard et en instruction' do
         expect(Dossier.late).to include(dossier_late)
         expect(Dossier.late).not_to include(dossier_on_time)
         expect(Dossier.late).not_to include(dossier_archived)
       end
     end
   end
   ```

2. Lance test et vérifie qu'il ÉCHOUE :
   ```bash
   bundle exec rspec spec/models/dossier_spec.rb -e "late"
   # Attendu : 1 failure (undefined method `late')
   ```

3. Implémente le scope pour faire passer le test :
   ```ruby
   # app/models/dossier.rb

   scope :late, -> {
     where('date_limite < ?', Date.today)
       .where(state: :en_instruction)
   }
   ```

4. Lance test et vérifie qu'il PASSE :
   ```bash
   bundle exec rspec spec/models/dossier_spec.rb -e "late"
   # Attendu : 1 example, 0 failures ✅
   ```

### Étape 3 : Tests Controller (30min)

1. Écris test pour filtre controller :
   ```ruby
   # spec/controllers/instructeur/dossiers_controller_spec.rb

   describe '#index' do
     context 'avec filter=late' do
       it 'affiche uniquement dossiers en retard' do
         dossier_late = create(:dossier, date_limite: 2.days.ago, state: :en_instruction)
         dossier_on_time = create(:dossier, date_limite: 2.days.from_now)

         get :index, params: { filter: 'late' }

         expect(assigns(:dossiers)).to include(dossier_late)
         expect(assigns(:dossiers)).not_to include(dossier_on_time)
       end
     end
   end
   ```

2. Implémente dans controller :
   ```ruby
   # app/controllers/instructeur/dossiers_controller.rb

   def index
     @dossiers = policy_scope(Dossier)

     if params[:filter] == 'late'
       @dossiers = @dossiers.late
     end

     @dossiers = @dossiers.page(params[:page])
   end
   ```

3. Vérifie test passe

### Étape 4 : Tests System (UI) (45min)

1. Écris test system pour UI :
   ```ruby
   # spec/system/instructeur/dossier_filter_spec.rb

   describe 'Filtre dossiers en retard' do
     let(:instructeur) { create(:instructeur) }

     before do
       login_as(instructeur, scope: :instructeur)
       create(:dossier, date_limite: 2.days.ago, state: :en_instruction, numero: '111')
       create(:dossier, date_limite: 2.days.from_now, state: :en_instruction, numero: '222')
     end

     scenario 'Instructeur filtre dossiers en retard' do
       visit instructeur_dossiers_path

       # Bouton visible avec count
       expect(page).to have_button('En retard (1)')

       # Click sur filtre
       click_button 'En retard (1)'

       # URL change
       expect(current_url).to include('filter=late')

       # Seul dossier en retard affiché
       expect(page).to have_content('111')
       expect(page).not_to have_content('222')
     end

     scenario 'Bouton accessible au clavier (RGAA)' do
       visit instructeur_dossiers_path

       button = find_button('En retard (1)')
       expect(button['aria-label']).to eq('Filtrer les dossiers en retard')
     end
   end
   ```

2. Implémente la vue :
   ```erb
   <!-- app/views/instructeur/dossiers/index.html.erb -->

   <div class="filters">
     <%= button_tag "En retard (#{Dossier.late.count})",
           type: 'button',
           class: 'fr-btn fr-btn--secondary',
           data: { turbo_method: :get, turbo_action: 'replace' },
           onclick: "window.location.href='#{instructeur_dossiers_path(filter: 'late')}'",
           aria: { label: 'Filtrer les dossiers en retard' } %>
   </div>

   <!-- Liste dossiers -->
   <% @dossiers.each do |dossier| %>
     <%= render 'dossier_card', dossier: dossier %>
   <% end %>
   ```

3. Lance tests system :
   ```bash
   bundle exec rspec spec/system/instructeur/dossier_filter_spec.rb
   ```

### Étape 5 : Vérifications (30min)

**A. Accessibilité (RGAA 4)**
```bash
# Vérifier aria-label présent
grep -n "aria-label" app/views/instructeur/dossiers/index.html.erb
```

**B. Performance (N+1)**
```ruby
# Dans console
Dossier.late.to_sql
# Vérifier que SQL est optimisé
```

**C. Sécurité (Authorization)**
```ruby
# Vérifier que policy_scope est utilisé
grep "policy_scope" app/controllers/instructeur/dossiers_controller.rb
```

**D. Tests Complets**
```bash
# Tous les tests model
bundle exec rspec spec/models/dossier_spec.rb

# Tous les tests controller
bundle exec rspec spec/controllers/instructeur/dossiers_controller_spec.rb

# Tous les tests system
bundle exec rspec spec/system/instructeur/
```

### Étape 6 : Rubocop & Coverage (15min)

1. Lance Rubocop sur fichiers modifiés :
   ```bash
   bundle exec rubocop app/models/dossier.rb \
                         app/controllers/instructeur/dossiers_controller.rb \
                         app/views/instructeur/dossiers/index.html.erb
   ```

2. Vérifie coverage :
   ```bash
   COVERAGE=true bundle exec rspec spec/models/dossier_spec.rb
   # Vérifier ≥ 80%
   ```

### Étape 7 : Commit (10min)

```bash
git add app/models/dossier.rb \
        app/controllers/instructeur/dossiers_controller.rb \
        app/views/instructeur/dossiers/index.html.erb \
        spec/models/dossier_spec.rb \
        spec/controllers/instructeur/dossiers_controller_spec.rb \
        spec/system/instructeur/dossier_filter_spec.rb

git commit -m "$(cat <<'EOF'
feat: Add late dossiers filter for instructeurs

Allow instructeurs to filter dossiers with overdue date_limite.

Changes:
- Add Dossier.late scope (date_limite < today)
- Add filter param to instructeur/dossiers#index
- Add "En retard" button in dossiers list view
- RGAA 4 compliant (aria-label on button)

Tests:
- Model specs for late scope
- Controller specs for filter param
- System specs for UI interaction

Closes #[ISSUE_NUMBER]

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Étape 8 : Rapport (15min)

Écris un résumé de la feature implémentée (format ci-dessous)

## Contraintes IMPORTANTES

**✅ AUTORISÉ (fais-le sans demander) :**
- Lire la spec fonctionnelle
- Écrire tests (TDD)
- Implémenter code (model → controller → view)
- Lancer tests
- Vérifier RGAA, perf, sécurité
- Commit les changements

**❌ INTERDIT :**
- Implémenter code AVANT tests (TDD obligatoire)
- Ignorer contraintes RGAA/sécurité/perf
- Commit si tests échouent ou coverage < 80%
- Ajouter features non spécifiées (scope creep)
- Modifier > 5 fichiers (si > 5 → STOP et demande)

**⚠️ SI PROBLÈME :**
- Spec ambiguë → pose 1-2 questions de clarification
- Impact > 5 fichiers → STOP et demande validation
- Tests régressent → rollback et explique
- Tu bloques > 2h → STOP et explique où tu bloques

## Checkpoints Jidoka

**À 1h :**
- [ ] Tests model écrits et passent ?
- [ ] Scope implémenté correctement ?
- Si NON → STOP et demande aide

**À 2h :**
- [ ] Tests controller + system écrits ?
- [ ] UI implémentée ?
- [ ] RGAA respecté ?
- Si NON → STOP et explique

**Avant commit :**
- [ ] Tous tests passent (model + controller + system) ?
- [ ] Coverage ≥ 80% ?
- [ ] Rubocop clean ?
- [ ] RGAA + sécurité + perf vérifiés ?

## Format du Rapport

```markdown
## Rapport Implémentation Feature

### 1. Feature Implémentée

**Titre :** Filtre "Dossiers en retard" pour instructeurs

**User Story :**
En tant qu'instructeur, je veux filtrer les dossiers en retard.

**Acceptance Criteria :** 8/8 ✅

### 2. Changements Apportés

**Fichiers modifiés : 6**

**Model (app/models/dossier.rb) :**
- Ajout scope `.late` (date_limite < today, state: en_instruction)
- Lignes : +4

**Controller (app/controllers/instructeur/dossiers_controller.rb) :**
- Ajout filtre conditionnel si params[:filter] == 'late'
- Lignes : +4

**View (app/views/instructeur/dossiers/index.html.erb) :**
- Ajout bouton "En retard (count)"
- ARIA-label pour accessibilité
- Lignes : +7

**Tests (spec/) :**
- spec/models/dossier_spec.rb : +15 lignes
- spec/controllers/instructeur/dossiers_controller_spec.rb : +12 lignes
- spec/system/instructeur/dossier_filter_spec.rb : +25 lignes (nouveau fichier)

### 3. Tests

**Coverage :**
- Model : 100% (scope late testé)
- Controller : 95% (filter testé)
- System : 100% (UI testée)

**Résultats :**
```bash
# Model
bundle exec rspec spec/models/dossier_spec.rb
=> 45 examples, 0 failures ✅

# Controller
bundle exec rspec spec/controllers/instructeur/dossiers_controller_spec.rb
=> 32 examples, 0 failures ✅

# System
bundle exec rspec spec/system/instructeur/dossier_filter_spec.rb
=> 2 examples, 0 failures ✅
```

**Régression :** AUCUNE
- Suite complète : 1250 examples, 0 failures ✅

### 4. Conformité

**RGAA 4 (Accessibilité) :**
- ✅ aria-label sur bouton
- ✅ Contraste couleurs (DSFR)
- ✅ Focus clavier visible

**Sécurité :**
- ✅ policy_scope utilisé (authorization Pundit)
- ✅ Pas de SQL injection (scope paramétré)
- ✅ Accessible instructeurs uniquement

**Performance :**
- ✅ SQL optimisé (index sur date_limite existant)
- ✅ Pas de N+1 détecté
- ✅ Count badge calculé efficacement

**Rubocop :**
- ✅ 0 offenses

### 5. Résultat

**Status :** ✅ SUCCÈS

**Temps :** 3h20min
- Compréhension : 30min
- Tests model : 30min
- Tests controller : 30min
- Tests system : 45min
- Implémentation view : 30min
- Vérifications : 30min
- Rubocop/commit : 15min

**Acceptance Criteria :** 8/8 ✅

**Problèmes rencontrés :** AUCUN

**Fichiers modifiés :** 6 (limite 5 → acceptable borderline)

### 6. Démo

**Before :**
Liste dossiers sans filtre en retard

**After :**
- Bouton "En retard (3)" visible
- Click → filtre actif, URL ?filter=late
- Seuls dossiers en retard affichés

**Screenshot :** [Si applicable]

### 7. Recommandations

**Merge :** ✅ OUI (prêt pour production)

**Tests manuels suggérés :**
1. Vérifier count badge correct en staging
2. Tester avec gros volume (> 100 dossiers en retard)

**Follow-up :**
- Considérer persistence filtre en session (nice to have)
- Ajouter filtre similaire pour autres critères (très urgent, etc.)
```

## Time Budget
**Total : 4h max**
- Compréhension & plan : 30min
- Tests model : 30min
- Tests controller : 30min
- Tests system : 45min
- Implémentation view : 30min
- Vérifications (RGAA, perf, sécu) : 30min
- Rubocop & coverage : 15min
- Commit : 10min
- Rapport : 15min

Si tu dépasses 4h → arrête et dis pourquoi.

Bonne chance ! 🚀
```

---

## Critères de Succès POC

**Ce POC est réussi si :**
- [ ] Claude comprend spec fonctionnelle sans clarification
- [ ] Approche TDD appliquée (tests avant code)
- [ ] Feature implémentée complètement (model + controller + view)
- [ ] Tous tests passent (model + controller + system)
- [ ] Coverage ≥ 80%
- [ ] RGAA 4 respecté
- [ ] Temps < 4h
- [ ] Rapport clair et actionnable
- [ ] Code mergeable tel quel

**Ce POC est partiellement réussi si :**
- [ ] Feature correcte mais > 4h
- [ ] 1-2 questions sur spec fonctionnelle
- [ ] Tests passent mais coverage 70-80%

**Ce POC échoue si :**
- [ ] Feature incomplète
- [ ] Tests échouent
- [ ] RGAA non respecté
- [ ] Bloqué > 5h
- [ ] Supervision constante nécessaire

---

## Notes

**Pourquoi ce POC est important :**
- Test complet end-to-end (full stack)
- Valide capacité TDD autonome
- Teste respect contraintes (RGAA, sécurité, perf)
- Plus proche de vraies features quotidiennes

**Ce qu'on apprend :**
- Claude peut faire TDD en autonome ?
- Respect des contraintes est naturel ?
- Rapport feature est actionnable ?

---

## Prochaines Étapes

**Une fois ce fichier créé :**
1. Créer worktree POC
2. Copier la spec fonctionnelle dans le prompt
3. Lancer Claude avec le prompt ci-dessus
4. Observer sans intervenir (checkpoints 1h et 2h)
5. Noter le temps écoulé
6. Review le code et tests
7. Documenter dans `learnings/poc-5-simple-feature-results.md`

---

*Setup créé le : 2026-03-09*
