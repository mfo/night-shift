# Proposition d'Amélioration - essentials.md

**Date :** 2026-03-11
**Proposé par :** Agent Claude
**Contexte :** POC 4-features - Implémentation refactoring tunnel_id (Session reconstruction git history)

---

## 🎯 Problème Identifié

**Situation observée :**
Lors de l'implémentation de la feature tunnel_id, l'historique git initial contenait 30 commits désordonnés mélangant :
- Fixes successifs après échecs
- Refactoring technique et améliorations UX dans le même commit
- Tests éparpillés ou manquants
- Ordre illogique (UX avant le refactoring technique qui le nécessite)

Résultat : historique "dégueulasse" (dixit user), difficile à review, non-atomic.

**Fréquence :**
- **Première occurrence** sur POC 4-features
- **Risque récurrent** sur toute feature complexe multi-étapes

**Impact :**
- **Temps perdu :** 30-45min pour reconstruire l'historique proprement
- **Charge mentale :** ÉLEVÉE - difficulté à structurer pendant l'implémentation
- **Risque :** PR non-reviewable, confusion sur l'ordre des changements, tests difficiles à isoler

**Preuve/Exemples :**
- Session 4 (2026-03-11) : 30 commits initiaux → reconstruction nécessaire → 7 commits finaux
- Commits initiaux :
  ```
  d5f548b108 fix(simpliscore): gestion du changement de schema en cours de tunnel
  bb26cd60ca cleanup: remove TunnelFinder and legacy code
  fe096c26fd tests: update controller and component specs (FIRST GREEN COMMIT) 🟢
  23674dbbcc tests: update system specs for tunnel_id workflow
  dddec3ea54 views: update all links to use new_simplify entry point
  ...25 autres commits...
  ```

---

## ✅ Solution Proposée

### Type d'Amélioration
- [x] Nouveau pattern pré-approuvé
- [ ] Nouvelle interdiction
- [x] Nouveau checkpoint
- [ ] Clarification existante
- [ ] Nouvelle commande utile
- [ ] Autre : [préciser]

### Contenu Proposé

**Texte à ajouter dans essentials.md :**

```markdown
## Git Strategy - Atomic Commits par Nature de Changement

### Pattern Recommandé

Pour features complexes touchant multiple couches (DB → Backend → Frontend → Tests), **planifier la structure de commits AVANT l'implémentation** :

**Structure type (7 commits atomiques) :**

1. **db: [description migration]**
   - Migrations DB (add column, indexes, constraints)
   - Maintenance tasks (backfill)
   - Schema.rb
   - Tests de la maintenance task

2. **model: [description validations/queries]**
   - Validations model
   - Query Objects si logique répétée ≥3 fois
   - Factory updates (générer nouvelles données)
   - Specs model + query objects

3. **backend: [description routes/controller/jobs]**
   - Routes (nouvelles + modifications)
   - Controller actions (concern ou controller)
   - Jobs (signature updates, breaking changes documentés)
   - Specs controller

4. **frontend: [description components/views]**
   - Components (mise à jour liens, props)
   - Views (templates ERB/HAML)
   - Specs components

5. **cleanup: [description code legacy]**
   - Suppression code obsolète (services, helpers)
   - Suppression routes legacy
   - Suppression fichiers inutilisés

6. **fix(scope): [description amélioration UX/DX]**
   - Améliorations UX (wording, typo, a11y)
   - Améliorations DX (messages erreur, logs)
   - Non lié au refactoring technique

7. **tests: [description tests system]**
   - Tests system end-to-end
   - Tests d'intégration multi-couches
   - Scénarios complets utilisateur

**Pourquoi cet ordre ?**
- **DB d'abord** : fondations sur lesquelles tout repose
- **Model ensuite** : valide que les données sont bien contraintes
- **Backend puis Frontend** : backend expose les APIs, frontend les consomme
- **Cleanup après** : on voit ce qui est vraiment obsolète une fois la migration faite
- **UX séparé** : découple technique et cosmétique (facilite review)
- **Tests system en dernier** : teste le flow complet une fois tout intégré

**Chaque commit doit :**
- ✅ Compiler (pas d'erreur syntax)
- ✅ Avoir ses tests unitaires (sauf commit 7)
- ✅ Documenter les breaking changes (si applicable)
- ✅ Être reviewable indépendamment

**Si > 7 commits :**
C'est peut-être trop complexe. Considérer découper la feature.

**Si < 4 commits :**
Peut-être trop groupé. Vérifier si DB/Backend/Frontend peuvent être séparés.

### Checkpoint Pré-Implémentation

**AVANT de commencer à coder, TOUJOURS écrire un fichier `COMMIT_PLAN.md` :**

```markdown
# Plan de Commits - Feature [NOM]

## Commits Prévus (7)

1. **db: add [table/column]**
   - Fichiers : db/migrate/*, db/schema.rb, app/tasks/maintenance/*
   - Tests : spec/tasks/maintenance/*

2. **model: validations [entity]**
   - Fichiers : app/models/*, app/queries/*
   - Tests : spec/models/*, spec/queries/*, spec/factories/*

3. **backend: implement [feature] (routes + controller + jobs)**
   - Fichiers : config/routes.rb, app/controllers/*, app/jobs/*
   - Tests : spec/controllers/*
   - Breaking : [documenter call-sites impactés]

4. **frontend: migrate [components] to [pattern]**
   - Fichiers : app/components/*, app/views/*
   - Tests : spec/components/*

5. **cleanup: remove [legacy code]**
   - Fichiers : app/services/* (deleted), config/routes.rb

6. **fix([scope]): amélioration UX**
   - Fichiers : app/components/*/fr.yml, app/models/*/config.rb

7. **tests: add system specs for [feature]**
   - Fichiers : spec/system/*

## Estimation
- Temps total : [X]h
- Par commit : [détail]
```

**Usage du COMMIT_PLAN.md :**
1. Écrit AVANT le premier `git add`
2. User le valide (ou ajuste)
3. Agent suit le plan à la lettre
4. Checkpoints : après chaque commit, vérifier cohérence avec le plan

**Si déviation nécessaire :**
→ Mettre à jour COMMIT_PLAN.md et demander validation user

### Commandes Git pour Reconstruction (si raté)

Si l'historique est déjà "dégueulasse", reconstruction possible :

```bash
# 1. Sauvegarder la branche actuelle
git branch backup-[branche]-$(date +%Y%m%d-%H%M%S)

# 2. Reset soft vers main (garde changements en staging)
git reset --soft main

# 3. Unstage tout
git reset HEAD

# 4. Reconstruire commit par commit selon COMMIT_PLAN.md
git add [fichiers commit 1]
git commit -m "[message commit 1]"

git add [fichiers commit 2]
git commit -m "[message commit 2]"

# etc.
```

**Temps reconstruction typique :** 30-45min pour 7 commits
```

**Section cible :** Nouvelle section "Git Strategy"

**Placement :** Après "Testing Strategy", avant "Performance Guidelines"

---

## 🧪 Validation

### Hypothèse

**Si on planifie la structure de commits AVANT l'implémentation (COMMIT_PLAN.md), alors :**
1. L'historique sera atomic et reviewable du premier coup (pas de reconstruction)
2. Claude ne mélangera pas technique et UX dans un même commit
3. Les tests seront au bon endroit (unitaires avec code, system à la fin)
4. Le temps total sera réduit (pas de reconstruction à 30-45min)

### Critères de Succès

**Cette amélioration sera considérée comme réussie si :**
1. **Sur 3 prochaines features complexes** : ≥2 ont un historique propre du premier coup (sans reconstruction)
2. **Temps de reconstruction** : réduit de 30-45min → 0-10min (juste ajustements mineurs)
3. **Review PR** : user dit "historique clean" sans demander de `git rebase`
4. **Commits atomiques** : chaque commit compile et passe ses tests unitaires

**À mesurer sur :** 3 prochaines features POC 4-features (ou projets similaires)

### Risques

**Risques potentiels de cette amélioration :**
- **Rigidité excessive** (probabilité MOYENNE) → Mitigation : COMMIT_PLAN.md ajustable en cours de route
- **Overhead planning** (probabilité FAIBLE) → Mitigation : plan = 10-15min, économie = 30-45min
- **Découpage trop fin** (probabilité FAIBLE) → Mitigation : guideline "4-7 commits idéal"

---

## 📊 Impact Estimé

### Tâches Concernées
- **Types de tâches :** Features complexes multi-couches (DB + Backend + Frontend)
- **Fréquence estimée :** 2-4 features/mois sur POC 4-features
- **Volume total :** Toutes features nécessitant ≥5 fichiers modifiés sur ≥3 couches

### Gain Espéré

**Par tâche :**
- Temps gagné : 30-45min (reconstruction évitée)
- Questions évitées : 3-5 (clarifications sur ordre de commits)
- Risque d'erreur réduit : ÉLEVÉ (pas de mélange technique/UX)
- Charge mentale : RÉDUITE (plan clair à suivre)

**Par mois (si fréquence = 3 features/mois) :**
- Temps total gagné : 90-135min
- Review PR plus rapide : ~30min/PR économisées

### Coût

**Coût d'implémentation :**
- Temps rédaction COMMIT_PLAN.md : 10-15min/feature
- Temps validation user : 5min/feature
- Risque confusion : FAIBLE (template clair)

**ROI estimé :** POSITIF (économie 30min, coût 15min → +15min net/feature)

---

## 🔄 Itération

### Version Proposée

**v1 (cette proposition) :**
```markdown
## Git Strategy - Atomic Commits par Nature de Changement

[Voir "Contenu Proposé" ci-dessus]
```

**Pourquoi cette formulation :**
- **"par Nature de Changement"** : met l'accent sur la logique (DB vs Backend vs Frontend)
- **"7 commits atomiques"** : guideline concrète (ni trop peu, ni trop)
- **COMMIT_PLAN.md checkpoint** : force la réflexion AVANT le code
- **Ordre justifié** : explique pourquoi DB → Model → Backend → Frontend
- **Commandes reconstruction** : filet de sécurité si raté

### Évolutions Futures Possibles

**Si v1 validée, on pourrait ensuite :**
- Automatiser génération COMMIT_PLAN.md (script ou agent)
- Template COMMIT_PLAN.md par type de feature (CRUD, refactoring, migration)
- Checkpoint automatique : "git hook pre-commit vérifie cohérence avec plan"

**Si v1 invalide, alternatives :**
- Version simplifiée : juste guideline "DB → Backend → Frontend" sans COMMIT_PLAN.md
- Version renforcée : COMMIT_PLAN.md obligatoire (pas juste recommandé)

---

## 📝 Historique (après test)

### Test 1
**Date :** 2026-03-11
**Tâche :** Session 4 - Reconstruction historique tunnel_id (a posteriori)
**Résultat :** ✅ Validé (reconstruction réussie, 30 commits → 7 commits propres)
**Observations :**
- Reconstruction manuelle a pris 2-3h (avec user guidant chaque commit)
- Historique final parfaitement structuré selon pattern DB → Model → Backend → Frontend → Cleanup → UX → Tests
- User satisfait : "c'est bon tu peux commiter"
- **Learning :** Si COMMIT_PLAN.md existait avant, reconstruction inutile

### Test 2
**Date :** [À venir - prochaine feature POC 4]
**Tâche :** [Prochaine feature avec COMMIT_PLAN.md]
**Résultat :** [À compléter]
**Observations :** [À compléter]

### Décision Finale
- [ ] ✅ **ACCEPTÉ** - Intégré dans essentials.md le [DATE]
- [ ] ⚠️ **ACCEPTÉ avec modifications** - Version modifiée : [lien]
- [x] 🔄 **À RETESTER** - Sur prochaine feature POC 4 avec COMMIT_PLAN.md
- [ ] ❌ **REJETÉ** - Raison : [pourquoi]

---

## 💡 Learnings de Cette Proposition

**Ce que cette amélioration révèle sur :**

### Le Projet
- **Complexité multi-couches** : Features touchent souvent 4-5 couches (DB, Model, Backend, Frontend, Tests)
- **Découplage nécessaire** : Technique vs UX = vraie séparation cognitive
- **Breaking changes fréquents** : Refactoring implique souvent changements de signature (ex: ImproveProcedureJob)

### L'Agent-Friendliness
- **Agent peut suivre un plan** : Si COMMIT_PLAN.md existe, agent le suit à la lettre
- **Agent ne planifie pas naturellement** : Sans guideline, agent fait "ce qui marche" (commits au fil de l'eau)
- **Agent bon reconstructeur** : Capable de réorganiser 30 commits → 7 propres si guidé

### Le Process Kaizen
- **Post-mortem utile** : Reconstruire a posteriori aide à voir le pattern idéal
- **Planning > Correction** : 15min de plan évitent 45min de reconstruction
- **Template efficace** : COMMIT_PLAN.md = faible coût, haut gain

---

## ⚠️ Template d'Usage

**Quand utiliser COMMIT_PLAN.md :**
- ✅ Feature touchant ≥3 couches (DB, Backend, Frontend)
- ✅ Feature avec migrations DB
- ✅ Feature avec breaking changes
- ✅ Refactoring architectural

**Quand NE PAS utiliser :**
- ❌ Fix 1-liner dans 1 fichier
- ❌ Feature < 3 fichiers modifiés
- ❌ Hotfix urgent (pas le temps de planifier)

**Principe :** Plan si complexité justifie. Pas de COMMIT_PLAN.md pour un bouton CSS.

---

## 🔗 Références

**Session :** Session 4 - Reconstruction historique git (2026-03-11)
**Contexte :** POC 4-features - Implémentation refactoring tunnel_id
**Résultat :** 7 commits atomiques production-ready
**Historique final :**
```
82fda894b8 tests: ajout tests system complets pour workflow tunnel_id
a6a66972c3 fix(simpliscore): amélioration UX (wording, typographie, stepper)
eb8d2b3a3e cleanup: suppression TunnelFinder (remplacé par TunnelFinishedQuery)
2ed76ebec6 frontend: migration components et views vers tunnel_id
c930637ed3 backend: implémentation workflow tunnel_id (routes, controller, jobs)
e9444abedc model: validations tunnel_id et query TunnelFinishedQuery
7baffc3c6d db: ajout colonne tunnel_id pour workflow simpliscore
```

---

**Note :** Cette amélioration suit le cycle PDCA (Plan-Do-Check-Act) du Kaizen.
**Status :** 🔄 En validation - À tester sur prochaine feature POC 4
