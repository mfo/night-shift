# Structure du Projet Night Shift

**Version :** 2.0 (après réorganisation)

---

## 📁 Arborescence Complète

```
night-shift/
│
├── README.md                       # 📘 Vision & méthodologie Toyotiste
├── STRUCTURE.md                    # 📐 Ce fichier (architecture)
├── ROADMAP.md                      # 🗺️ Roadmap & état du projet
├── WORKFLOW.md                     # 📋 Guide pratique POCs & kaizen
├── QUICKSTART.md                   # ⚡ Démarrage rapide
├── essentials.md                   # 📚 Base connaissances (patterns)
│
├── epics/                          # 📋 Spécifications par epic
│   ├── 1-memoire.md                # Gestion contexte (.claude/)
│   ├── 2-taches.md                 # Workflow & scripts
│   └── 3-use-cases.md              # Types de tâches
│
├── pocs/                           # 🧪 Proof of Concepts
│   ├── README.md                   # Guide POCs
│   ├── overview.md                 # Vue d'ensemble 4 POCs
│   │
│   ├── 1-haml/                     # POC 1 : Migration HAML→ERB
│   │   ├── setup.md                # Setup POC 1
│   │   └── results.md              # Résultats POC 1 (template)
│   │
│   ├── 2-tests/                    # POC 2 : Optimisation tests lents
│   │   └── setup.md
│   │
│   ├── 3-bugs/                     # POC 3 : Investigation bugs
│   │   └── setup.md
│   │
│   └── 4-features/                 # POC 4 : Features simples
│       └── setup.md
│
├── kaizen/                         # 📈 Amélioration continue
│   ├── README.md                   # Guide templates kaizen
│   ├── 1-haml/                     # Kaizen POC 1
│   ├── 3-bugs/                     # Kaizen POC 3
│   │   ├── iteration-1/            # Bug mistral-api
│   │   └── iteration-2/            # Bug snowball renewal
│   ├── 4-features/                 # Kaizen POC 4
│   │   └── iteration-1/            # Feature simpliscore
│   └── templates/
│       ├── task.md                 # Kaizen par tâche (10-15min)
│       ├── weekly.md               # Synthèse hebdo (30-45min)
│       └── improvement.md          # Propositions amélioration
│
├── CLAUDE.md                       # 📋 Instructions pour Claude sur ce projet
│
└── .claude/                        # ⚙️ Config Claude Code (versionné)
    ├── settings.local.json         # Paramètres locaux
    └── skills/                     # Skills évolutifs (v1→v2→v3)
        ├── haml-migration/         # POC 1
        ├── investigate-bug/        # POC 3 - Investigation
        ├── bugfix/                 # POC 3 - Implémentation fix
        ├── feature-spec/           # POC 4 - Phase 0 (spec)
        ├── feature-plan/           # POC 4 - Phase 1 (plan commits)
        ├── feature-implementation/ # POC 4 - Phase 2 (code)
        ├── feature-review/         # POC 4 - Phase 3 (review)
        └── review-3-amigos/        # Transversal - Review team (PM+UX+Dev)
```

---

## 🎯 Rôle de Chaque Dossier

### `/` (Racine)
**Fichiers stratégiques :**
- `README.md` : Vision Toyotiste, théorie, méthodologie
- `STRUCTURE.md` : Ce fichier (architecture projet)
- `ROADMAP.md` : Roadmap détaillée, état du projet, décisions
- `WORKFLOW.md` : Guide pratique POCs & kaizen
- `QUICKSTART.md` : Démarrage rapide
- `essentials.md` : Base connaissances (patterns découverts)

### `epics/`
**Spécifications de référence**

Chaque epic documente une dimension du système :
- `1-memoire.md` : Architecture `.claude/`, gestion contexte
- `2-taches.md` : Workflow, scripts, gestion queue
- `3-use-cases.md` : 5 types de tâches identifiés

**Quand lire :** Quand tu veux comprendre comment un aspect du système doit fonctionner

**Quand modifier :** Rarement. Ce sont des specs de référence.

### `pocs/`
**Expérimentations et validation**

Structure par POC :
```
pocs/X-nom/
├── setup.md          # Setup complet du POC
├── results.md        # Template résultats (à remplir après)
└── (futures versions)
```

**Fichiers clés :**
- `README.md` : Guide d'utilisation des POCs
- `overview.md` : Vue d'ensemble 4 POCs, planning

**Workflow :**
1. Lire `setup.md`
2. Exécuter POC
3. Remplir `results.md`
4. Documenter kaizen

### `kaizen/`
**Amélioration continue**

**Templates :**
- `task.md` : Après chaque tâche/POC (10-15min)
- `weekly.md` : Fin de semaine (30-45min)
- `improvement.md` : Proposition amélioration essentials.md

**Principe :** Petites améliorations continues > grandes révolutions

**Outputs typiques :**
- Ajout pattern à essentials.md
- Évolution skill (v1 → v2)
- Identification tâche agent-friendly vs unfriendly

### `.claude/`
**Configuration Claude Code (versionné)**

**Contenu :**
- `settings.local.json` : Paramètres locaux du projet
- `skills/` : Skills pour lancer les agents

**Pourquoi versionné ?**
- ✅ **Skills = cœur du projet** : Les skills sont le résultat principal de Night Shift
- ✅ **Traçabilité évolution** : Git log montre amélioration v1 → v2 → v3
- ✅ **Reproductibilité** : Autre dev peut rejouer POCs à l'identique
- ✅ **Kaizen documenté** : Chaque amélioration skill = commit avec rationale

**Non versionné (futur) :**
- Config locale personnelle (`.claude/config/` si ajoutée)
- Cache ou tokens temporaires

---

## 🔄 Structure dans Worktrees POC

Chaque worktree POC a sa propre structure `.claude/` :

```
demarche.numerique.gouv.fr-poc-haml/
├── app/
├── spec/
└── .claude/
    ├── context/
    │   └── essentials.md           # Copié depuis night-shift
    ├── skills/
    │   └── haml-migration/         # Skill évolutif (v1, v2...)
    │       └── SKILL.md
    ├── commands/                   # Slash commands (optionnel)
    │   └── haml-migrate.md         # /haml-migrate [fichier]
    └── tasks/                      # Tasks queue (futur)
        ├── queue/
        ├── in-progress/
        └── done/
```

**Pourquoi par worktree ?**
- Isolation : chaque POC a son environnement
- Pas de pollution du repo principal
- Facilite testing parallèle

---

## 📊 Flux d'Information

### 1. Préparation POC

```
epics/3-use-cases.md
    ↓
pocs/overview.md (décision quel POC)
    ↓
pocs/X-nom/setup.md (préparation détaillée)
    ↓
Création worktree + .claude/
```

### 2. Exécution POC

```
Worktree POC
    ↓
.claude/skills/X/SKILL.md (skill v1)
    ↓
Claude exécute (fire-and-forget)
    ↓
Résultats dans worktree
```

### 3. Documentation Kaizen

```
Résultats POC
    ↓
pocs/X-nom/results.md (remplir template)
    ↓
kaizen/templates/task.md (learnings)
    ↓
Décisions :
  - Améliorer essentials.md ?
  - Créer skill v2 ?
  - Continuer POC suivant ?
```

### 4. Amélioration Continue

```
Kaizen task.md
    ↓
Patterns récurrents (≥2 fois) ?
    ↓
kaizen/templates/improvement.md
    ↓
Tester proposition
    ↓
Si validé → Intégrer essentials.md ou skill v2
```

---

## 🎯 Principes d'Organisation

### 1. Séparation Spec / Expérimentation / Learning

- **`epics/`** : Specs de référence (stable)
- **`pocs/`** : Expérimentations (actif, évolue)
- **`kaizen/`** : Learnings et amélioration (output)

### 2. Versioning Skills

Les skills évoluent :
```
.claude/skills/haml-migration/SKILL.md
  v1.0 (2026-03-09) - Initial POC 1
  v1.1 (2026-03-10) - Après kaizen : ajout checkpoint 15min
  v2.0 (2026-03-12) - Refonte suite 5 POCs : temps ajustés
```

Historique dans le fichier skill lui-même.

### 3. Templates Réutilisables

Tous les templates dans `kaizen/templates/` :
- Copier dans worktree POC
- Remplir après chaque tâche
- Alimenter amélioration continue

### 4. Documentation Progressive

On ne documente PAS tout d'avance :
- `essentials.md` commence minimal (100 lignes)
- S'enrichit via kaizen (patterns récurrents)
- Prompts évoluent via retours terrain

---

## 🚀 Quick Reference

### Démarrer un nouveau POC

```bash
# 1. Lire le setup
cat pocs/X-nom/setup.md

# 2. Créer worktree (commande dans setup.md)
cd ../demarche.numerique.gouv.fr
git worktree add -b poc-X ../demarche.numerique.gouv.fr-poc-X main

# 3. Setup .claude/ dans worktree
cd ../demarche.numerique.gouv.fr-poc-X
mkdir -p .claude/{context,skills,commands}

# 4. Copier essentials.md
# (Existe déjà pour POC 1)

# 5. Lancer POC selon prompt
```

### Documenter résultats POC

```bash
# 1. Remplir results.md
cd night-shift/pocs/X-nom/
# Éditer results.md avec résultats réels

# 2. Remplir kaizen task
cd night-shift/kaizen/
cp templates/task.md ../pocs/X-nom/kaizen-YYYY-MM-DD.md
# Remplir learnings

# 3. Identifier actions
# → Améliorer essentials.md ?
# → Créer skill v2 ?
```

---

## 📖 Guides par Rôle

### Tu veux lancer un POC
→ Lis `pocs/README.md` + `pocs/X-nom/setup.md`

### Tu veux comprendre la vision
→ Lis `README.md`

### Tu veux créer un nouveau type de tâche
→ Lis `epics/3-use-cases.md` + inspire-toi d'un setup POC existant

### Tu veux améliorer le process
→ Lis `kaizen/README.md` + utilise templates

### Tu veux comprendre l'architecture
→ Tu es déjà ici ! (`STRUCTURE.md`)

---

**Note :** Cette structure évolue. Si elle devient trop complexe, on simplifie (kaizen).
