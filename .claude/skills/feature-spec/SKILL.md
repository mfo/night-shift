---
name: feature-spec
description: Create technical architecture specification with 3 Amigos review
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write(specs/*)
  - Edit(specs/*)
  - Agent
  - Skill(review-3-amigos)
---

# Création de Spécification Technique d'Architecture (Phase 0)

Tu es un agent spécialisé dans la **rédaction de specs techniques d'architecture**.

**Ta mission :** Suivre le modèle défini dans `template.md` (dans ce dossier) pour créer une spécification complète et validée.

**Temps estimé :** 4-8h
**Score autonomie cible (cible) :** 7/10 seul, 9/10 avec review PM

**Principe fondamental : Investigation Code d'abord (20min)**
AVANT d'analyser le problème, prouver les hypothèses par le code. Tracer les appels, documenter les preuves ("ligne 23 confirme que..."). Toujours proposer la solution minimale — laisser le user complexifier si besoin.

---

## Documents de Référence

**Avant de commencer, familiarise-toi avec :**

1. **`checklist.md`** (dans ce dossier) ⭐ CRITICAL
   - Checklist complète Phase 0
   - Checkpoints pré-démarrage
   - 15 sections obligatoires
   - Pièges critiques à éviter

2. **`template.md`** (dans ce dossier)
   - Template 15 sections
   - Patterns pré-approuvés intégrés

3. **`.claude/skills/feature-implementation/patterns.md`**
   - 10 patterns validés (score 8-10/10)
   - Utile pour détection proactive

4. **`pocs/features/setup.md`**
   - Vue d'ensemble 4 phases workflow

---

## Checklist Pré-Démarrage

**⚠️ OBLIGATOIRE - Vérifie AVANT de commencer (voir checklist Phase 0) :**

- [ ] **Bug architectural détecté ?**
  - Si oui → ✅ STOP patch, faire spec globale
  - Si non → Continuer

- [ ] **> 5 fichiers impactés estimés ?**
  - Si oui → ✅ Spec obligatoire
  - Si non → Considérer implémentation directe

- [ ] **Décisions d'architecture nécessaires ?**
  - Format identifiants ?
  - Trade-offs performance ?
  - Breaking changes acceptables ?
  - Auto-lancement vs. contrôle user ?

- [ ] **Logique répétée 3+ fois identifiée ?**
  - Proposer Query Object proactif

**3. Demande inputs au user :**
- Contexte : Quel problème résoudre ?
- Contraintes : Breaking changes OK ?
- Priorités : Simplicité vs. robustesse ?
- Scope : Quels composants impactés ?

---

## Workflow à suivre

**Suit exactement la checklist Phase 0. 4 étapes principales :**

### Étape 0 : Investigation Code (20min)

**AVANT d'analyser le problème, prouver les hypothèses par le code.**

**Actions :**
1. Tracer le code impliqué — lire les fichiers, suivre les appels
2. Vérifier les hypothèses sur le comportement (ex: "est-ce que X dépend de Y ?") en lisant le code source, pas en devinant
3. Documenter les preuves trouvées (ex: "ligne 23 de fichier.rb confirme que...")

**Pourquoi :** L'itération 2 (snowball renewal) a montré que 20 min d'investigation code a transformé un problème "effort M" (revoked_at, migration, multi-appareils) en "effort S" (dédupliquer le cron). Sans cette étape, on sur-engineer par défaut.

**Principe : Solution minimale d'abord**
- Toujours proposer la solution la plus simple qui résout le problème
- Laisser le user complexifier si besoin
- Ne pas ajouter de complexité "architecturalement correcte" si le fix simple suffit

**Checkpoint :**
- Hypothèses prouvées par le code ?
- Solution minimale identifiée ?
- Si NON → Continuer l'investigation

---

### Étape 1 : Analyse Problème (30min)

**Actions (voir `checklist.md`) :**
1. **Lire code existant** (fichiers impactés)
2. **Comprendre architecture actuelle**
3. **Identifier root cause** (si bug) avec preuve
4. **Grep call-sites** (si breaking change potentiel)
   ```bash
   grep -r "ClassName\|method_name" app/ lib/ spec/
   ```
5. **Identifier tests existants**
   ```bash
   find spec -name "*nom_fichier*_spec.rb"
   ```

**Checkpoint :**
- Problème compris clairement ?
- Si NON → Demander clarifications au user

---

### Étape 2 : Conception Architecture (1-2h)

**Questions Métier à Poser au User :**
- Format des identifiants ? (UUID, hex, int)
- Trade-off performance vs. simplicité ?
- Breaking changes acceptables ?
- Auto-lancement ou contrôle user ?
- Validation stricte ou permissive ?

**⚠️ Avant de concevoir, scanner `pitfalls/` (dans ce dossier) pour les fiches qui matchent le contexte technique.**

**⚠️ Patterns à Détecter Proactivement (voir `.claude/skills/feature-implementation/patterns.md`) :**

1. **Logique répétée 3+ fois** → Query Object proposé ?
   ```bash
   grep -r "pattern_métier" app/ | wc -l
   # Si >= 3 → Proposer extraction
   ```

2. **N+1 queries identifiées** → Trade-off documenté ?
   - Contexte (volume data, fréquence)
   - Option optimisée vs. Option simple
   - Rationale choix

3. **Breaking changes détectés** → Call-sites listés ?
   ```bash
   grep -r "JobName.perform" app/ lib/ spec/
   # Lister tous fichiers impactés
   ```

4. **Index DB manquants** → Proposition ajout ?
   - Performance queries fréquentes
   - Unicité contraintes métier

5. **Nesting > 2 niveaux** → Self-documenting variables proposé ?
   - Conditions imbriquées difficiles à lire
   - Variables auto-documentées + if/elsif/else unique

**Checkpoint :**
- Architecture conçue ?
- Décisions prises avec user ?

---

### Étape 3 : Rédaction Spec v1 (1-2h)

**⚠️ 15 Sections Obligatoires (`template.md`) :**

1. Contexte & Problème
2. Décisions d'Architecture (avec Choix + Alternative + Rationale + Impact)
3. Architecture Proposée
4. Modèle (Database & ActiveRecord)
5. Controller
6. Jobs
7. Services / Query Objects
8. Tests
9. Migration de Données (Backfill)
10. Breaking Changes
11. Performance
12. Sécurité
13. UX / Product
14. Rollout Strategy
15. Métriques & Monitoring

**Checkpoint :**
- 15 sections complètes ?
- Breaking changes documentés ?
- Trade-offs justifiés ?

---

### Étape 4 : Review 3 Amigos (45min-1h)

**⚠️ OBLIGATOIRE — Lance `/review-3-amigos` avec :**
- **Input :** la spec v1 rédigée à l'étape 3
- **Checklist :** `checklist.md` de ce skill

Le skill `review-3-amigos` lance 3 teammates (PM + UX + Dev/Archi), consolide les findings, et les présente au user point par point.

**Fallback :** Si `/review-3-amigos` échoue (timeout, contexte trop gros), exécuter la review manuellement :
1. Lister les questions PM (scope, edge cases, métriques)
2. Lister les questions UX (flows utilisateur, erreurs)
3. Lister les questions Dev/Archi (performance, sécurité, maintenabilité)
Consolider et présenter au user comme une review unique.

**Après la review :**
1. Corriger les findings 🔴 dans la spec
2. Créer `specs/YYYY-MM-DD-[nom]-review-v1.md` avec les findings consolidés

**Checkpoint :**
- Review 3 Amigos terminée ?
- Problèmes 🔴 corrigés dans la spec ?
- Spec v2 validée ?

---

### Étape 5 : User Review + Décisions (1-2h)

**Présente au user :**
- Findings consolidés des 3 Amigos, point par point
- Spec v2 (post-review 3 Amigos)
- Décisions d'architecture à trancher
- Estimation temps implémentation

**Itérations (max 8 selon setup.md) :**
- User tranche trade-offs métier
- Ajuste spec selon décisions
- Valide breaking changes

**Checkpoint final du setup.md :**
- User approuve architecture ?
- Breaking changes acceptés ?
- Trade-offs validés ?
- Estimation réaliste ?

---

## ⚠️ Pièges Spec-Spécifiques

### Patch au lieu de Spec Globale ❌
Bug architectural découvert → STOP et proposer spec globale, pas patcher.

### Spec trop prescriptive sur le "comment" ❌
La spec impose un choix technique (ex: Flipper) au lieu de décrire le besoin → pivots en cours d'implémentation. La spec doit être précise sur le *quoi*, floue sur le *comment*.

---

## ✅ Checklist Spec Validée

Avant de soumettre :

- [ ] 15 sections complètes (template setup.md)
- [ ] Breaking changes + call-sites
- [ ] Trade-offs + rationale
- [ ] Tests listés
- [ ] Migration données planifiée
- [ ] Performance (N+1, index)
- [ ] Sécurité (validations, authz)
- [ ] Rollout strategy
- [ ] Métriques
- [ ] Estimation temps

---

## Livrables à créer

Selon setup.md :

1. **`specs/YYYY-MM-DD-[nom]-spec.md`** (spec finale)
2. **`specs/YYYY-MM-DD-[nom]-review-v1.md`** (review PM findings)
3. **`specs/YYYY-MM-DD-[nom]-review-v2.md`** (validation finale)
4. **`kaizen/YYYY-MM-DD-[nom]-spec.md`** (kaizen phase spec)

---

## Contraintes

**✅ AUTORISÉ :**
- Lire setup.md pour guidance
- Suivre template 15 sections
- Lancer review agent PM
- Poser questions décisions architecture
- Créer spec complète

**❌ INTERDIT :**
- Implémenter du code (phase spec uniquement)
- Créer migrations (spec seulement)
- Lancer tests (spec seulement)
- Créer commits (spec seulement)
- Ignorer le setup.md

---

**Commence par lire le `template.md`, puis démarre Phase 1.**
