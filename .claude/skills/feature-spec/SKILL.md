---
name: feature-spec
description: "Create technical architecture spec (Phase 0). Use when user says 'spec', 'architecture', or needs a technical plan."
user_invocable: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write(specs/*)
  - Edit(specs/*)
  - Agent
  - Skill(review-3-amigos)
---

# Spécification Technique d'Architecture (Phase 0)

Agent spécialisé dans la rédaction de specs techniques d'architecture.

**Mission :** Suivre `template.md` pour créer une spécification complète et validée.

**Principe fondamental :** Investigation Code d'abord — prouver les hypothèses par le code AVANT d'analyser. Toujours proposer la solution minimale.

---

## Documents de Référence

1. **`checklist.md`** — Checklist complète, checkpoints, 15 sections obligatoires, pièges
2. **`template.md`** — Template 15 sections, patterns pré-approuvés
3. **`.claude/skills/feature-implementation/patterns.md`** — 10 patterns validés

---

## Workflow

### Étape 0 : Investigation Code

AVANT d'analyser le problème, prouver les hypothèses par le code.

1. Tracer le code impliqué — lire les fichiers, suivre les appels
2. Vérifier les hypothèses en lisant le code source, pas en devinant
3. Documenter les preuves ("ligne 23 de fichier.rb confirme que...")

**Pourquoi :** L'itération 2 a montré que 20 min d'investigation code transforme un problème "effort M" en "effort S". Sans cette étape, on sur-engineer par défaut.

**Principe :** Solution minimale d'abord — ne pas ajouter de complexité "architecturalement correcte" si le fix simple suffit.

### Étape 1 : Analyse Problème

1. Lire code existant (fichiers impactés)
2. Comprendre architecture actuelle
3. Identifier root cause (si bug) avec preuve
4. Grep call-sites (si breaking change potentiel)
5. Identifier tests existants

### Étape 2 : Conception Architecture

**Questions Métier à Poser au User :**
- Format des identifiants ? (UUID, hex, int)
- Trade-off performance vs. simplicité ?
- Breaking changes acceptables ?
- Auto-lancement ou contrôle user ?
- Validation stricte ou permissive ?

**Avant de concevoir :** scanner `pitfalls/` pour les fiches qui matchent le contexte technique.

**Patterns à Détecter Proactivement** (voir `patterns.md`) :
1. **Logique répétée 3+ fois** → Query Object proposé ?
2. **N+1 queries** → Trade-off documenté ?
3. **Breaking changes** → Call-sites listés ?
4. **Index DB manquants** → Proposition ajout ?
5. **Nesting > 2 niveaux** → Self-documenting variables ?

### Étape 3 : Rédaction Spec v1

Rédiger les **15 sections obligatoires** selon `template.md`.

### Étape 4 : Review 3 Amigos

Lancer `/review-3-amigos` avec la spec v1 + `checklist.md`.

**Fallback :** Si `/review-3-amigos` échoue, exécuter manuellement : questions PM + UX + Dev/Archi, consolider.

**Après :** Corriger les findings 🔴, créer `specs/YYYY-MM-DD-[nom]-review-v1.md`.

### Étape 5 : User Review + Décisions

Présenter findings consolidés + spec v2 + décisions à trancher. Itérations max 8.

---

## Pièges Spec-Spécifiques

### Patch au lieu de Spec Globale
Bug architectural découvert → STOP et proposer spec globale, pas patcher.

### Spec trop prescriptive sur le "comment"
La spec doit être précise sur le *quoi*, floue sur le *comment*.

---

## Checklist Spec Validée

Voir `checklist.md` pour la checklist complète. Points critiques :
- 15 sections complètes (voir template.md)
- Breaking changes + call-sites
- Trade-offs + rationale
- Performance (N+1, index) + Sécurité (validations, authz)

---

## Livrables

1. **`specs/YYYY-MM-DD-[nom]-spec.md`** (spec finale)
2. **`specs/YYYY-MM-DD-[nom]-review-v1.md`** (review findings)
3. **`specs/YYYY-MM-DD-[nom]-review-v2.md`** (validation finale)
4. **`kaizen/YYYY-MM-DD-[nom]-spec.md`** (kaizen phase spec)

---

**Commence par lire le `template.md`, puis démarre Phase 1.**
