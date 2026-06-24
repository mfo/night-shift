---
name: feature-spec
description: "Create technical architecture spec (Stage 0). Use when user says 'spec', 'architecture', or needs a technical plan."
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write(specs/*)
  - Edit(specs/*)
  - Agent
  - Skill(review-3-amigos)
  - Bash(gh issue view:*)
  - Bash(gh api:*)
  - Bash(.claude/skills/feature-spec/find-procedure.sh:*)
---

# Spécification Technique d'Architecture (Stage 0)

Agent spécialisé dans la rédaction de specs techniques d'architecture.

**Mission :** Suivre `template.md` pour créer une spécification complète et validée.

**Principe fondamental :** Clarifier l'intent avec le user d'abord, investiguer le code ensuite. Toujours proposer la solution minimale.

---

## Sizing Feature

| Taille | Critère | Workflow |
|--------|---------|---------|
| Micro | 1-2 fichiers, pas de migration | Skip spec → plan direct |
| Small | 3-5 fichiers, pas de breaking change | Sections 1, 3, 8, 12 + user review |
| Medium | 6-15 fichiers, ou migration, ou breaking change | Spec complète (16 sections) |
| Large | 16+ fichiers, ou multi-système | Spec complète + 3-amigos + rollout plan |

L'agent propose le sizing, le user valide. En cas de doute → niveau supérieur.
Le user peut toujours forcer un niveau différent.

---

## Documents de Référence

1. **`checklist.md`** — Checklist complète, checkpoints, 16 sections obligatoires, pièges
2. **`template.md`** — Template 16 sections, patterns pré-approuvés
3. **`.claude/skills/feature-implementation/patterns.md`** — Référence unique pour les patterns validés (ne pas dupliquer ici)

---

## Workflow

### Étape -1 : Interview de clarification (AVANT tout code)

**Ne pas lire le code. Ne pas concevoir. Clarifier.**

**Si l'input est une URL GitHub issue :**
1. Fetch le contenu : `gh issue view URL --json title,body,labels`
2. Fetch les commentaires : `gh api repos/OWNER/REPO/issues/NUMBER/comments`
3. Présenter au user : titre ETQ, besoin, solution proposée, maquettes UX
4. Enchaîner sur la reformulation ci-dessous normalement

Le user arrive avec une demande. Reformuler ce qu'on a compris et le présenter :

> "Je comprends que tu veux que **[persona]** puisse **[action]** parce que **[problème]**. Aujourd'hui **[situation actuelle / contournement]**. Ce qui implique **[conséquence/contrainte non dite par le user]**. C'est correct ?"

La reformulation DOIT inclure une implication que le user n'a pas dite (effet de bord, cas limite, contrainte implicite). Si le user corrige cette inférence, c'est un signal de compréhension réelle — pas juste un écho.

Si la reformulation a des trous, poser UNE question à la fois sur la dimension la plus floue :

| Dimension | Question à poser au user |
|-----------|------------------------|
| **Intent** | "Pourquoi on fait ça ? Quel problème ça résout ?" |
| **Outcome** | "Quel état final tu veux ? À quoi ça ressemble quand c'est fini ?" |
| **Scope** | "Jusqu'où ça va ? Quels cas sont couverts ?" |
| **Non-goals** | "Qu'est-ce qui est explicitement hors scope ?" |
| **Constraints** | "Quelles limites ? (techniques, deadline, backward compat…)" |
| **Affected roles** | "Quels rôles sont impactés ? (admin, instructeur, usager…)" |
| **Affected states** | "Quels états/transitions sont touchés ?" |
| **Failure mode** | "Que se passe-t-il si ça échoue ? Fallback ? Erreur visible ?" |
| **Test landscape** | "Quels tests existants couvrent ce périmètre ?" |
| **Success criteria** | "Comment on sait que c'est fini et que ça marche ?" |

**Règles :**
- Une question par round. Pas de batches.
- Cibler la dimension la plus floue.
- Reformuler la réponse du user avant de passer à la question suivante.
- **Continuer tant qu'une dimension critique est floue** (Intent, Outcome, ou Scope).
- Ne pas dépasser 5-6 rounds. Si c'est encore flou → le user a besoin de réfléchir, pas d'un agent.
- La reformulation + question tient en 5 lignes max. Pas de mur de texte.

**Gate de sortie :** AVANT de passer à l'Étape 0, écrire le bloc structuré ci-dessous et demander validation explicite. Si le user n'a pas validé ce bloc, l'Étape 0 est inaccessible.

**Sortie :** Un bloc structuré co-écrit avec le user :
```
Intent : [pourquoi]
Outcome : [quoi]
Scope : [jusqu'où]
Non-goals : [pas ça]
Constraints : [limites]
Affected roles : [admin / instructeur / usager / ...]
Affected states : [transitions impactées — ex: en_construction → en_instruction]
Failure mode : [que se passe-t-il si ça échoue ? fallback ? erreur visible ?]
Test landscape : [tests existants sur le périmètre, tests à créer]
Success criteria :
- GIVEN [contexte] WHEN [action] THEN [résultat attendu]
```

Ce bloc devient la Section 1 "Contexte & Problème" de la spec.

**Si le user dit "débrouille-toi" :** écrire le bloc avec les hypothèses, marquer chaque dimension non validée `[hypothèse]`, et continuer. Signaler en début de spec que le cadrage n'est pas validé.

---

### Étape 0 : Investigation Code

APRÈS la clarification, prouver les hypothèses par le code.

1. Tracer le code impliqué — lire les fichiers, suivre les appels
2. Vérifier les hypothèses en lisant le code source, pas en devinant
3. Documenter les preuves ("ligne 23 de fichier.rb confirme que...")
4. Si le changement impacte l'interface, identifier une démarche de test avec les bons types de champs via `find-procedure.sh` (query ActiveRecord libre)

**Pourquoi :** L'itération 2 a montré que 20 min d'investigation code transforme un problème "effort M" en "effort S". Sans cette étape, on sur-engineer par défaut.

**Principe :** Solution minimale d'abord — ne pas ajouter de complexité "architecturalement correcte" si le fix simple suffit.

### Étape 1 : Analyse Problème

1. Lire code existant (fichiers impactés)
2. Comprendre architecture actuelle
3. Identifier root cause (si bug) avec preuve
4. Grep call-sites (si breaking change potentiel)
5. Identifier tests existants

### Étape 2 : Conception Architecture

**Questions techniques à poser au user :**
- Format des identifiants ? (UUID, hex, int)
- Trade-off performance vs. simplicité ?
- Breaking changes acceptables ?
- Auto-lancement ou contrôle user ?
- Validation stricte ou permissive ?

**Avant de concevoir :** scanner `pitfalls/` pour les fiches qui matchent le contexte technique.

**Patterns à Détecter Proactivement :** voir `../feature-implementation/patterns.md` pour la liste complète. En particulier : logique répétée 3+, N+1 queries, breaking changes, index DB manquants.

### Étape 3 : Rédaction Spec v1

Rédiger les **16 sections obligatoires** selon `template.md`.
La Section 1 reprend le bloc structuré de l'Étape -1 (co-écrit avec le user).

### Étape 4 : Review 3 Amigos

Lancer `/review-3-amigos` avec la spec v1 + `checklist.md`.

**Fallback :** Si `/review-3-amigos` échoue, exécuter manuellement : questions PM + UX + Dev/Archi, consolider.

**Après :** Corriger les findings 🔴, créer `specs/YYYY-MM-DD-[nom]-review-v1.md`.
**Écrire le rapport :** le rapport consolidé est écrit par review-3-amigos dans `specs/`.

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
- 16 sections complètes (voir template.md)
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

## Output Structuré

Terminer le skill par un bloc JSON dans un code fence. Le harness valide la présence des champs requis.

```json
{
  "status": "draft_v1 | validated",
  "issue_source": "https://github.com/... | null",
  "sizing": "micro | small | medium | large",
  "sections_completed": 16,
  "success_criteria": ["GIVEN ... WHEN ... THEN ..."],
  "affected_roles": ["admin", "instructeur", "usager"],
  "spec_path": "specs/YYYY-MM-DD-nom-spec.md"
}
```

---

**Commence par reformuler la demande du user (Étape -1), puis lis le `template.md`.**
