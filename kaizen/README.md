# Templates Kaizen

Ces templates structurent l'apprentissage continu (kaizen) du projet Night Shift.

---

## 📋 Templates Disponibles

### 1. `task-kaizen.md` - Kaizen par Tâche

**Quand l'utiliser :**
- Après chaque tâche/POC complété
- Pour documenter les learnings immédiats
- Pour identifier les améliorations rapides

**Durée de remplissage :** 10-15 minutes

**Focus :**
- Ce qui a marché / coincé
- Autonomie (fire-and-forget ?)
- Améliorations essentials.md/prompts

**Output :**
- Learnings actionnables
- Propositions d'amélioration concrètes
- Score agent-friendly

---

### 2. `weekly-kaizen.md` - Synthèse Hebdomadaire

**Quand l'utiliser :**
- Fin de chaque semaine
- Pour synthétiser plusieurs tâches
- Pour identifier les patterns récurrents

**Durée de remplissage :** 30-45 minutes

**Focus :**
- Patterns "agent-friendly" vs "agent-challenging"
- Problèmes récurrents
- Impact global (temps, charge mentale, qualité)

**Output :**
- Classification des types de tâches
- Objectifs semaine suivante
- Métriques d'amélioration

---

### 3. `essentials-improvement.md` - Proposition d'Amélioration

**Quand l'utiliser :**
- Pattern récurrent identifié (≥ 2 occurrences)
- Proposition d'ajout/modification à essentials.md
- Besoin de tester une hypothèse structurée

**Durée de remplissage :** 20-30 minutes

**Focus :**
- Problème mesuré avec impact
- Solution testable
- Critères de succès clairs

**Output :**
- Proposition formelle
- Plan de validation
- Décision GO/NO-GO après tests

---

## 🔄 Workflow Kaizen

```
┌─────────────────┐
│   Tâche POC     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ task-kaizen.md  │ ← Learnings immédiats
└────────┬────────┘
         │
         ▼
   Pattern récurrent ? ──YES──┐
         │                    │
         NO                   ▼
         │         ┌──────────────────────┐
         │         │ essentials-          │
         │         │ improvement.md       │
         │         └──────────┬───────────┘
         │                    │
         │                    ▼
         │              Test & Validate
         │                    │
         ▼                    ▼
┌─────────────────────────────────┐
│     Fin de semaine              │
└────────┬────────────────────────┘
         │
         ▼
┌─────────────────┐
│ weekly-kaizen.md│ ← Synthèse & patterns
└────────┬────────┘
         │
         ▼
   Objectifs semaine N+1
```

---

## 🎯 Principes d'Utilisation

### Minimalisme
- **Templates = guides**, pas camisoles
- Remplir les sections pertinentes uniquement
- Préférer 5 lignes utiles à 50 lignes vides

### Mesure
- Focus sur métriques actionnables :
  - Temps (mais pas seulement)
  - **Charge mentale** (fire-and-forget ?)
  - Agent-friendly score (1-10)
  - Qualité (mergeable tel quel ?)

### Action
- Chaque kaizen → actions concrètes
- Pas de learnings "théoriques"
- Si pas d'action → pas besoin de kaizen détaillé

---

## 📊 Fréquence Recommandée

| Template | Fréquence | Durée | Obligatoire ? |
|----------|-----------|-------|---------------|
| task-kaizen.md | Après chaque tâche | 10-15min | ✅ Oui |
| weekly-kaizen.md | Fin de semaine | 30-45min | ✅ Oui |
| essentials-improvement.md | Sur besoin | 20-30min | ⚠️ Si pattern récurrent |

---

## 💡 Exemples d'Usage

### Exemple 1 : POC HAML Migration Réussi

1. **Immédiat :** Remplir `task-kaizen.md`
   - Score agent-friendly : 8/10
   - Learning : "Les fichiers < 15 lignes sans logique métier sont très agent-friendly"
   - Proposition : Ajouter pattern pré-approuvé pour HAML < 20 lignes

2. **Si pattern confirmé (après 2-3 migrations similaires) :** Créer `essentials-improvement.md`
   - Proposition : Pré-approuver migrations HAML simples (< 20 lignes)
   - Test sur 5 prochaines migrations
   - Si succès → intégrer dans essentials.md

3. **Fin de semaine :** Synthèse dans `weekly-kaizen.md`
   - Pattern identifié : "Migrations HAML simples" = agent-friendly
   - Volume estimé : ~30 fichiers restants
   - Objectif S+1 : Tester batch de 5 migrations

### Exemple 2 : Refacto Complexe Échoué

1. **Immédiat :** Remplir `task-kaizen.md`
   - Score agent-friendly : 3/10
   - Learning : "Refacto avec logique métier complexe nécessite supervision"
   - Blocage : Contexte métier insuffisant
   - **PAS de proposition essentials-improvement** (cas unique)

2. **Fin de semaine :** Noter dans `weekly-kaizen.md`
   - Tâche "agent-unfriendly" : Refacto logique métier
   - Décision : Reporter ces tâches ou augmenter contexte métier

---

## 🚀 Quick Start

### Après votre première tâche POC :

```bash
# 1. Copier le template
cp learnings/templates/task-kaizen.md learnings/kaizen-poc-1-haml.md

# 2. Remplir les sections pertinentes (10min)
# Focus : ce qui a marché, ce qui a coincé, agent-friendly score

# 3. Identifier actions
# → Amélioration essentials.md ?
# → Amélioration prompt ?
# → Pattern à tester ?
```

### Fin de votre première semaine :

```bash
# 1. Copier le template
cp learnings/templates/weekly-kaizen.md learnings/kaizen-week-1.md

# 2. Synthétiser les task-kaizen de la semaine (30min)
# Focus : patterns récurrents, types de tâches agent-friendly

# 3. Définir objectifs semaine suivante
# → Quels types de tâches tester ?
# → Quelles améliorations process ?
```

---

**Rappel :** Le kaizen n'est pas de la bureaucratie. C'est l'outil pour apprendre à construire une chaîne de production logicielle adaptée à VOTRE projet.

**Règle d'or :** Si un template ne vous aide pas à apprendre ou décider → ne le remplissez pas.
