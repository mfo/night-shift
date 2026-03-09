# POCs - Proof of Concepts

**Objectif :** Tester et valider 4 types de tâches "agent-friendly" par ordre de complexité

---

## 📋 Les 4 POCs

| # | Type | Complexité | Temps | Status |
|---|------|------------|-------|--------|
| 1 | [HAML→ERB](1-haml/) | LOW | 30-45min | ✅ Ready |
| 2 | [Tests Lents](2-tests/) | MEDIUM | 45-60min | ✅ Ready |
| 3 | [Bug Sentry](3-bugs/) | MEDIUM | 2-3h | ✅ Ready |
| 4 | [Feature Simple](4-features/) | MEDIUM-HIGH | 2-4h | ✅ Ready |

Voir [overview.md](overview.md) pour détails complets.

---

## 🏗️ Structure par POC

Chaque POC suit cette structure :

```
pocs/X-nom/
├── setup.md           # Setup détaillé du POC
├── results.md         # Template résultats (à remplir après)
└── (versions futures)
    ├── v2-setup.md    # Si itération nécessaire
    └── kaizen.md      # Learnings du POC
```

---

## 🔄 Workflow POC

### 1. Préparation
- Lire `setup.md` du POC
- Créer worktree dédié
- Copier prompt dans worktree

### 2. Exécution
- Lancer Claude avec le prompt
- Observer sans intervenir (fire-and-forget)
- Noter temps écoulé

### 3. Documentation
- Remplir `results.md` avec résultats réels
- Remplir kaizen (`kaizen/templates/task.md`)
- Identifier améliorations pour essentials.md

### 4. Kaizen
- Analyser : qu'est-ce qui a marché/coincé ?
- Proposer amélioration prompt (v2)
- Mettre à jour essentials.md si pattern récurrent

---

## 📦 Prompts Évolutifs

Chaque POC a son prompt qui évolue via kaizen :

```
.claude/prompts/
├── haml-migration.md      # v1 → v2 → v3...
├── optimize-tests.md
├── investigate-bug.md
└── simple-feature.md
```

### Cycle d'Évolution Prompt

```
v1 (initial)
    ↓
  POC lancé
    ↓
  Kaizen
    ↓
Learnings identifiés → v2 (amélioré)
    ↓
  Re-test
    ↓
Si OK → Utiliser v2 en prod
Si KO → v3 (ajustements)
```

---

## ⚡ Slash Commands

Pour faciliter l'utilisation, chaque POC peut avoir un slash command :

```bash
# Dans worktree POC
/haml-migrate app/views/path/to/file.html.haml
/optimize-test spec/path/to/slow_spec.rb
/investigate-bug sentry-issue-123
/implement-feature issue-456
```

**Setup slash commands :**
Créer dans `.claude/commands/` du worktree

---

## 🎯 Critères de Succès POC

### POC Réussi (≥ 4/5)
- ✅ Objectif atteint (code mergeable)
- ✅ Tests passent
- ✅ Temps < budget (+20% max)
- ✅ Fire-and-forget (0-1 intervention)
- ✅ Rapport clair et actionnable

### POC Partiellement Réussi (3/5)
- ⚠️ Objectif atteint avec ajustements manuels
- ⚠️ Tests passent mais temps dépassé
- ⚠️ 2-3 interventions nécessaires

### POC Échoué (≤ 2/5)
- ❌ Code non mergeable
- ❌ Tests échouent
- ❌ Temps dépassé > 50%
- ❌ Supervision constante nécessaire

---

## 📊 Tracking

Après chaque POC, documenter dans `kaizen/` :

**Métriques clés :**
- Temps réel vs estimé
- Questions Claude a posées
- Blocages rencontrés
- Agent-friendly score (1-10)
- Fire-and-forget réussi ? (OUI/NON)

**Décisions :**
- Continuer avec POC suivant ?
- Itérer sur ce POC (v2) ?
- Ajuster prompts/essentials.md ?

---

## 🚀 Quick Start

### Lancer POC 1 (HAML Migration)

```bash
# 1. Le worktree POC 1 existe déjà
cd /Users/mfo/dev/demarche.numerique.gouv.fr-poc-haml

# 2. Vérifier que essentials.md est à jour
cat .claude/context/essentials.md

# 3. Lancer Claude avec le prompt
# Copier le prompt de pocs/1-haml/setup.md
# OU utiliser slash command (si créé)

# 4. Observer (fire-and-forget)
# Noter heure début/fin

# 5. Documenter résultats
# Remplir pocs/1-haml/results.md
# Remplir kaizen/templates/task.md
```

---

## 📖 Documentation

- [Overview](overview.md) : Vue d'ensemble détaillée
- [Kaizen Templates](../kaizen/README.md) : Templates pour learnings
- [README Principal](../README.md) : Vision Toyotiste

---

**Principe :** Chaque POC = Learning. L'échec est une donnée, pas un problème.
