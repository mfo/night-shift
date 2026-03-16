# Epic 1 : Gestion de la Mémoire 🧠

**Status :** ✅ Phase 1 Implémentée (essentials.md)
**Effort :** Phase 1: 2h | Phase 2 (5 fichiers): 4-6h
**Priorité :** HIGH (bloque tout le reste)

---

## 🎯 Objectif

**Problème :** Claude n'a pas de mémoire entre sessions. Il repart de zéro à chaque fois.

**Solution :** Créer une mémoire externe persistante via fichiers `.md` structurés

**Résultat attendu :**
- Agents démarrent avec contexte complet du projet
- Pas besoin de ré-expliquer les patterns à chaque session
- Réduction des demandes d'autorisation (actions pré-approuvées documentées)

---

## 📁 Architecture `.claude/` (Par Worktree)

### Phase 1 : Structure Minimaliste (✅ Implémentée)

**Principe :** Commencer minimal (100 lignes), enrichir via kaizen.

```
worktree/.claude/                     # Dans chaque worktree POC
├── context/
│   └── essentials.md                 # 100 lignes max (tout-en-un)
│
├── prompts/                          # Prompts versionnés
│   └── haml-migration.md             # v1.0, v1.1, v2.0...
│
└── commands/                         # Slash commands (optionnel)
    └── haml-migrate.md               # /haml-migrate [file]
```

**Learnings & Kaizen :** Stockés dans `night-shift/kaizen/` (à la racine), pas dans `.claude/`

### Phase 2 : Structure Complète (Si Phase 1 validée)

```
worktree/.claude/
├── context/                          # 5 fichiers spécialisés
│   ├── project-overview.md           # Architecture, conventions
│   ├── code-preferences.md           # Patterns, style, tests
│   ├── pre-approved-actions.md       # Actions sans demander
│   ├── critical-constraints.md       # Sécurité, RGAA, GraphQL
│   └── common-pitfalls.md            # Erreurs fréquentes
│
├── prompts/                          # Templates versionnés
│   ├── haml-migration.md
│   ├── optimize-tests.md
│   ├── bugfix.md
│   └── simple-feature.md
│
├── commands/                         # Slash commands
│   └── [1 par prompt]
│
└── tasks/                            # Queue locale (futur)
    ├── queue/
    ├── in-progress/
    └── done/
```

### Responsabilités

**`context/essentials.md`** (Phase 1) : Mémoire tout-en-un
- Patterns du projet
- Interdictions absolues
- Actions pré-approuvées
- Checkpoints (Jidoka)
- Commandes utiles
- **Relu au début de chaque tâche**

**`prompts/`** : Templates évolutifs
- Versionnés (v1.0 → v1.1 → v2.0)
- Évoluent via kaizen après chaque POC
- Variables à remplacer ({FICHIER}, {WORKTREE_PATH})

**`commands/`** : Slash commands (optionnel)
- Simplifient l'utilisation des prompts
- Ex: `/haml-migrate app/views/file.html.haml`

**Kaizen & Learnings :** Dans `night-shift/kaizen/` et `night-shift/pocs/`
- Séparés de `.claude/` (qui est local au worktree)
- Partagés entre tous les POCs

---

## 📝 Phase 1 : essentials.md (✅ Implémenté)

### Structure Actuelle

**Fichier unique :** `.claude/context/essentials.md` (~300 lignes)

**Sections :**
1. **Meta-Objectif** : Kaizen & Apprentissage
2. **Patterns du Projet** : Service Objects, HAML→ERB, conventions
3. **Interdictions Absolues** : Sécurité, RGAA 4, GraphQL, Tests
4. **Actions Pré-Approuvées** : Tests, Refactoring, Git & Commits
5. **Checkpoints (Jidoka)** : À 15min, 30min, avant commit
6. **Commandes Utiles** : Tests, Rubocop, Rails console
7. **Definition of Done** : Critères + format rapport

**Exemple actuel :** `/Users/mfo/dev/demarche.numerique.gouv.fr-poc-haml/.claude/context/essentials.md`

**Principe :** Tout-en-un, 100-300 lignes max. S'enrichit via kaizen (pas upfront).

---

## 📝 Phase 2 : 5 Fichiers Séparés (Futur - Si Nécessaire)

**Note :** Seulement si essentials.md dépasse 500 lignes ou devient difficile à maintenir.

### 1. `context/project-overview.md` (~100 lignes)

**Objectif :** Donner vision 360° du projet en 5min de lecture

**Contenu :**
- Architecture (Rails 7, PostgreSQL, Redis, Sidekiq, GraphQL)
- Structure codebase (app/models, app/services, spec/)
- Conventions (service objects, query objects, jobs)
- Localisation code clé (auth, policies, dossiers, API)

**Exemple :**
```markdown
# demarche.numerique.gouv.fr - Project Overview

## Architecture
- Rails 7+ monolithe
- PostgreSQL + Redis
- Sidekiq (jobs async)
- RSpec + Selenium (tests)
- ViewComponents (UI)
- GraphQL API (public)

## Structure
- app/models/ : Logique métier
- app/services/ : Service objects (actions métier)
- app/jobs/ : Background jobs
- app/components/ : ViewComponents
- spec/ : Tests (system, model, service, component)

## Conventions
- Service objects pour logique > 10 lignes
- Query objects pour requêtes complexes
- Form objects pour validations complexes
- Jobs pour async (pas de threads custom)

[...]
```

---

### 2. `context/code-preferences.md` (~200 lignes)

**Objectif :** Mes règles de code, patterns préférés, interdictions

**Contenu :**
- **Principes** : Simplicité > Flexibilité, Explicit > Implicit, DRY
- **Patterns** : Service objects, Query objects, Form objects (avec exemples code)
- **Interdictions** : Abstractions prématurées, metaprogramming complexe, god objects
- **Tests** : Types obligatoires (system, model, service), style (Arrange/Act/Assert)
- **Performance** : N+1 queries, caching, benchmarks
- **Organisation** : Models, services, UI, controllers

**Exemple de pattern :**
```ruby
# Service Object (bon pattern)
class DossierService
  def initialize(dossier)
    @dossier = dossier
  end

  def process
    # logique métier
  end
end

# Utilisation
DossierService.new(dossier).process
```

**Point clé :** Exemples concrets de "bon" vs "mauvais" code

---

### 3. `context/pre-approved-actions.md` (~150 lignes)

**Objectif :** **RÉDUIRE LES DEMANDES D'AUTORISATION**

**C'est le fichier le plus critique pour le workflow supervision minimale.**

**Contenu :**

**✅ Actions autorisées SANS DEMANDER :**
- Lancer tests (`bundle exec rspec`)
- Créer fichiers de test
- Extraire service objects (si méthode > 10 lignes)
- Corriger violations Rubocop
- Ajouter validations
- Optimiser N+1 queries évidentes
- Corriger typos, formatting

**❌ Actions NÉCESSITANT APPROBATION :**
- **Sécurité** : auth, permissions, policies
- **Base de données** : migrations (même simples)
- **Dépendances** : Gemfile, package.json
- **API GraphQL** : changements schéma
- **Breaking changes** : supprimer méthodes publiques, changer signatures
- **Déploiement** : CI/CD, scripts deploy
- **Performance critique** : changements impactant perf globale

**Checklist avant de coder :**
1. Ai-je lu et compris le contexte ?
2. Cette action est-elle pré-approuvée ?
3. Les tests passent-ils avant/après ?
4. Ai-je respecté les patterns ?

**Pourquoi c'est critique :**
Sans ce fichier, Claude demandera autorisation pour tout → casse le supervision minimale

---

### 4. `context/critical-constraints.md` (~250 lignes)

**Objectif :** Contraintes non-négociables du projet

**Contenu :**

**🚨 Contraintes non-négociables :**

1. **Sécurité**
   - Point d'attention permanent
   - Jamais de compromis
   - Vérifier autorisations (Pundit policies)

2. **Accessibilité (RGAA 4)**
   - **Accessibilité > UX** (non-négociable)
   - Keyboard navigation obligatoire
   - ARIA labels si nécessaire
   - Tests a11y dans system specs

3. **API GraphQL**
   - Jamais de breaking change
   - Toujours rétrocompatible
   - Deprecation warnings avant suppression

4. **Migrations**
   - Le plus grand soin (irréversibles)
   - Tester sur dataset réaliste
   - Prévoir rollback strategy

5. **Performance**
   - N+1 queries : inacceptable
   - Benchmark si changement suspect
   - Coverage min : 80%

**Exemples concrets :**
```erb
<!-- ✅ Bon : accessible -->
<button aria-label="Supprimer le dossier">
  <span aria-hidden="true">×</span>
</button>

<!-- ❌ Mauvais : pas accessible -->
<div onclick="delete()">×</div>
```

---

### 5. `context/common-pitfalls.md` (~300 lignes)

**Objectif :** Erreurs fréquentes à éviter (apprentissage par exemples)

**Contenu :**

**10 erreurs fréquentes avec exemples code :**

1. **N+1 Queries**
   ```ruby
   # ❌ N+1
   dossiers.each { |d| d.user.name }

   # ✅ Fix
   Dossier.includes(:user).each { |d| d.user.name }
   ```

2. **Forgot Strong Params**
   ```ruby
   # ❌ Dangereux
   Dossier.create(params[:dossier])

   # ✅ Sécurisé
   Dossier.create(dossier_params)
   ```

3. **Missing Accessibility Attributes**
4. **Incomplete Validations**
5. **God Objects**
6. **Tests Fragiles**
7. **Missing Test Coverage**
8. **Hardcoded Credentials**
9. **Breaking Changes GraphQL**
10. **Missing Indexes**

**Format :** Symptôme → Détection → Fix (avec code)

---

## 🚀 Plan d'Implémentation

### Phase 1 : Minimaliste (✅ Fait - 2h)

**1. Créer structure de base (30min)**
```bash
mkdir -p .claude/{context,prompts,commands}
```

**2. Créer essentials.md (1h30)**
- Copier template depuis `night-shift/pocs/1-haml/`
- Adapter au projet demarche.numerique.gouv.fr
- 100-300 lignes max (tout-en-un)

**3. Créer premier prompt versionné (30min)**
```bash
# Exemple : haml-migration.md
.claude/prompts/haml-migration.md  # v1.0
```

**Status :** ✅ Implémenté dans `/Users/mfo/dev/demarche.numerique.gouv.fr-poc-haml/.claude/`

---

### Phase 2 : 5 Fichiers Séparés (Si Nécessaire - 3-4h)

**Critères GO/NO-GO :**
- essentials.md > 500 lignes OU
- Devient difficile à naviguer OU
- Patterns trop différents par type de tâche

**Étape 1 : Créer structure complète (30min)**
```bash
mkdir -p .claude/{context,prompts,tasks/{queue,in-progress,done}}
```

**Étape 2 : Splitter essentials.md (3-4h)**

**Ordre recommandé :**

1. **project-overview.md** (30min)
   - Remplir architecture, structure, conventions
   - Basé sur README du repo DS

2. **pre-approved-actions.md** (45min)
   - Lister actions autorisées
   - Lister actions nécessitant approbation
   - Checklist avant de coder

3. **code-preferences.md** (1h)
   - Écrire principes
   - Exemples de patterns (service objects, query objects)
   - Interdictions
   - Tests, performance, organisation

4. **critical-constraints.md** (1h)
   - Sécurité, accessibilité, GraphQL, migrations, perf
   - Exemples concrets (code)
   - Points d'attention

5. **common-pitfalls.md** (1h)
   - Les 10 erreurs fréquentes
   - Symptôme → Détection → Fix
   - Exemples code

### Étape 3 : Review & Test (30min-1h)

**Checklist :**
- [ ] Les 5 fichiers sont complets
- [ ] Exemples de code sont corrects
- [ ] Pas de redondance entre fichiers
- [ ] Taille raisonnable (< 300 lignes par fichier)
- [ ] Facile à lire/scanner

**Test :**
- Lancer Claude avec prompt : "Lis .claude/context/*.md et résume en 5 bullet points"
- Vérifier qu'il comprend bien les contraintes

---

## ✅ Critères d'Acceptance

### Critères de Qualité

- [ ] Structure `.claude/` créée avec tous les dossiers
- [ ] 5 fichiers de contexte écrits et complets
- [ ] Chaque fichier < 300 lignes (lisible en 5-10min)
- [ ] Exemples de code présents et corrects
- [ ] README.md dans chaque dossier (explique le rôle)

### Critères de Validation

- [ ] Claude peut lire les 5 fichiers en < 2min (test manuel)
- [ ] Les contraintes sont claires (pas d'ambiguïté)
- [ ] Les actions pré-approuvées couvrent 80% des cas courants
- [ ] Les exemples de code sont exécutables (pas de pseudo-code)

### Critères d'Impact

- [ ] Réduction des demandes d'autorisation : objectif -80%
- [ ] Agents respectent les patterns dans 90% des cas
- [ ] Pas de violation de contraintes critiques (sécurité, RGAA)

---

## 📊 Métriques de Succès

**Pendant Phase 1 (expérimentation) :**

Tracker pour chaque tâche agent :
- Nombre de demandes d'autorisation (objectif : 0-1 par tâche)
- Nombre de violations de patterns (objectif : 0)
- Nombre de violations de contraintes critiques (objectif : 0)
- Temps de lecture des rapports (objectif : < 5min)

**Si problèmes détectés :**
→ Améliorer le fichier de contexte correspondant
→ Ajouter exemples concrets
→ Clarifier les règles ambiguës

---

## 🔗 Ressources

**Templates complets :**
Voir `SPEC-archive.md` sections 1-2 pour les contenus complets des 5 fichiers

**Références :**
- Roadmap projet : `roadmap.perso.md`
- README projet : `README.md`
- Repo DS : https://github.com/demarches-simplifiees/demarche.numerique.gouv.fr

---

## 🎯 Prochaines Étapes

**Après Epic 1 :**
→ Epic 3 : Créer les prompts templates (utiliseront les fichiers de contexte)
→ Epic 2 : Créer scripts de workflow (utiliseront la structure `.claude/`)

**Note :** Epic 1 est le fondement. Sans lui, les agents n'ont pas de mémoire.

---

*Epic 1 v1.0 - 2026-03-08*
