# Quick Start - Night Shift

---

## 🎯 Tu veux lancer POC 1 maintenant ?

### Option A : Slash Command (✅ Recommandé)

```bash
# 1. Le worktree existe déjà
cd /Users/mfo/dev/demarche.numerique.gouv.fr-poc-haml

# 2. Lancer Claude
claude

# 3. Utiliser le slash command
/haml-migrate app/views/release_notes/_announce.html.haml

# 4. Observer (supervision minimale)
# 5. Après : /results puis /kaizen
```

### Option B : Manuelle

```bash
# 1. Copier le prompt
cat /Users/mfo/dev/night-shift/pocs/1-haml/setup.md
# Lignes 53-197

# 2. Lancer Claude et coller
cd /Users/mfo/dev/demarche.numerique.gouv.fr-poc-haml
claude
# [Coller le prompt]
```

**Voir workflow complet :** `WORKFLOW.md`

---

## 📝 Après POC 1

### 1. Documenter Résultats (15min)

```bash
# Remplir template résultats
cd /Users/mfo/dev/night-shift/pocs/1-haml/
# Éditer results.md avec ce qui s'est passé réellement
```

### 2. Kaizen Task (10min)

```bash
cd /Users/mfo/dev/night-shift
cp kaizen/templates/task.md pocs/1-haml/kaizen-$(date +%Y-%m-%d).md

# Remplir :
# - Ce qui a marché
# - Ce qui a coincé
# - Agent-friendly score (1-10)
# - Propositions amélioration
```

### 3. Décider Suite (5min)

**Si POC 1 score ≥ 4/5 :**
→ Lancer POC 2 (Tests Lents)

**Si POC 1 score 3/5 :**
→ Itérer : améliorer prompt, retry POC 1 v2

**Si POC 1 score ≤ 2/5 :**
→ Analyser causes, revoir hypothèse supervision minimale

---

## 🗺️ Vue d'Ensemble Projet

### Pour Comprendre le Projet
- **Vision & Théorie :** `README.md`
- **Architecture :** `STRUCTURE.md`
- **Roadmap :** `roadmap.perso.md`

### Pour Lancer un POC
- **Guide POCs :** `pocs/README.md`
- **Vue d'ensemble :** `pocs/overview.md`
- **Setup POC 1 :** `pocs/1-haml/setup.md`

### Pour Documenter Learnings
- **Guide Kaizen :** `kaizen/README.md`
- **Templates :** `kaizen/templates/`

### Pour Comprendre Specs
- **Epics :** `epics/1-memoire.md`, `epics/2-taches.md`, `epics/3-use-cases.md`

---

## 🔧 Commandes Utiles

### Vérifier Structure

```bash
cd /Users/mfo/dev/night-shift
ls -la                    # Voir fichiers racine
ls -la pocs/              # Voir POCs
ls -la kaizen/templates/  # Voir templates
```

### Worktrees POC

```bash
# Voir worktrees existants
git worktree list

# POC 1 existe déjà :
# /Users/mfo/dev/demarche.numerique.gouv.fr-poc-haml
```

### Créer Nouveau Worktree (POC 2, 3, 4)

```bash
cd /Users/mfo/dev/demarche.numerique.gouv.fr

# POC 2 - Tests
git worktree add -b poc-optimize-tests ../demarche.numerique.gouv.fr-poc-tests main

# POC 3 - Bugs
git worktree add -b poc-bug-fix ../demarche.numerique.gouv.fr-poc-bug main

# POC 4 - Features
git worktree add -b poc-simple-feature ../demarche.numerique.gouv.fr-poc-feature main
```

---

## 📊 Structure Rapide

```
night-shift/
├── README.md                   # 📘 Vision Toyotiste
├── STRUCTURE.md                # 📐 Architecture
├── QUICKSTART.md               # ⚡ Ce fichier
│
├── epics/                      # 📋 Specs
│   ├── 1-memoire.md
│   ├── 2-taches.md
│   └── 3-use-cases.md
│
├── pocs/                       # 🧪 POCs
│   ├── README.md               # Guide
│   ├── overview.md             # Vue d'ensemble
│   ├── 1-haml/                 # POC 1 ✅
│   ├── 2-tests/                # POC 2 ✅
│   ├── 3-bugs/                 # POC 3 ✅
│   └── 4-features/             # POC 4 ✅
│
└── kaizen/                     # 📈 Amélioration
    ├── README.md
    └── templates/
        ├── task.md
        ├── weekly.md
        └── improvement.md
```

---

## ❓ FAQ

### Où est le prompt pour POC 1 ?
→ `pocs/1-haml/setup.md` (lignes 53-197)
→ OU `.claude/skills/haml-migration/SKILL.md` dans le worktree POC 1

### Comment créer un slash command ?
→ Voir `.claude/commands/haml-migrate.md` dans worktree POC 1 (exemple)

### Comment les prompts évoluent ?
1. Version initiale (v1) dans `.claude/skills/`
2. Lancer POC
3. Documenter kaizen
4. Identifier améliorations → créer v2
5. Re-tester
6. Si OK → utiliser v2 en prod

### essentials.md existe où ?
→ Déjà créé dans worktree POC 1 : `/Users/mfo/dev/demarche.numerique.gouv.fr-poc-haml/.claude/context/essentials.md`

### Planning suggéré ?
→ Voir `pocs/overview.md` section "Planning Suggéré - Semaine 1"

---

## 🚀 Action Immédiate

**Pour lancer POC 1 maintenant :**

```bash
cd /Users/mfo/dev/demarche.numerique.gouv.fr-poc-haml
claude
# Copier prompt de pocs/1-haml/setup.md
# Observer et documenter !
```

**Temps estimé :** 45min + 30min review + 15min kaizen = ~1h30 total

---

**Bon courage ! 🎯**
