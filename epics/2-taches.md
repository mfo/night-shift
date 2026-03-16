# Epic 2 : Gestion des Tâches 📋

**Status :** 📋 Phase 2 (Après validation POCs)
**Effort :** 3-4h
**Priorité :** MEDIUM (après validation supervision minimale sur POC 1-2)

**Note :** Phase 1 utilise lancement manuel (pas de queue, pas de scripts). Le système de queue sera implémenté seulement si POCs 1-2 validés (≥ 4/5).

---

## 🎯 Objectif

**Problème :** Pas de système pour queuer, prioriser, suivre les tâches des agents

**Solution MVP (Phase 2) :** Queuing manuel + scripts bash simples

**Résultat attendu :**
- Workflow supervision minimale fonctionnel
- Scripts pour lancer/review facilement
- Rapports structurés et actionnables

**Phase 1 (actuelle) :** Lancement manuel, documentation dans `pocs/`

---

## 📁 Structure Tasks

### Architecture

```
.claude/tasks/
├── queue/                    # Tâches à faire
│   ├── TEMPLATE.md          # Template vide
│   ├── bug-sentry-123.md
│   ├── migrate-haml-12.md
│   └── refacto-42.md
│
├── in-progress/             # Tâches en cours
│   └── bug-sentry-123.md   # Movée par script
│
└── done/                    # Rapports finalisés
    ├── TEMPLATE-report-simple.md
    ├── TEMPLATE-report-investigation.md
    ├── bug-sentry-123-report.md
    └── migrate-haml-12-report.md
```

### Workflow

```
1. QUEUE (manuel)
   ↓
   Je crée: .claude/tasks/queue/bug-123.md

2. LAUNCH (script)
   ↓
   bin/launch-night-task bug-123
   → Crée worktree
   → Move bug-123.md vers in-progress/
   → Lance Claude avec prompt structuré

3. WORK (autonome)
   ↓
   Claude travaille dans worktree isolé
   → Lit contexte
   → Exécute tâche
   → Écrit rapport dans done/

4. REVIEW (manuel)
   ↓
   Je lis: .claude/tasks/done/bug-123-report.md
   → Décision: merge / reject / ajuster
```

---

## 📝 Templates de Tâches

### 1. `tasks/queue/TEMPLATE.md`

**Format standard pour toute tâche :**

```markdown
# [TYPE] Titre Court

**Type :** Bug Investigation | HAML Migration | Refactoring | Test Optimization | Feature
**Priority :** LOW | MEDIUM | HIGH | CRITICAL
**Estimated Time :** 1-2h | 2-3h | 3-4h
**Created :** YYYY-MM-DD
**Worktree :** worktree-[task-id]

---

## Contexte

**Pourquoi cette tâche ?**
[Expliquer le besoin business ou technique]

**Impact si non fait :**
[Expliquer les risques/conséquences]

---

## Spec Détaillée

[Description précise de ce qui doit être fait]

**Pour bugs :**
- Stack trace complète
- Steps to reproduce (si connu)
- Données impactées
- Fréquence (nb occurrences)

**Pour features :**
- User story
- Acceptance criteria (liste à cocher)
- Wireframes/mocks (si disponibles)

**Pour refacto :**
- Localisation précise (fichier:ligne)
- Métrique actuelle (lignes, complexity)
- Objectif (métrique cible)

---

## Contraintes

**Obligatoires :**
- [ ] Tests doivent passer
- [ ] Respecter RGAA 4 (si UI)
- [ ] Pas de breaking change GraphQL
- [ ] Coverage ≥ 80%

**Spécifiques à cette tâche :**
- [Contrainte 1]
- [Contrainte 2]

---

## Livrable Attendu

- [ ] Code implémenté/fixé
- [ ] Tests écrits (type: system/model/service)
- [ ] Tests passent (100%)
- [ ] Rapport dans `.claude/tasks/done/[TASK_ID]-report.md`
- [ ] Commit avec message clair

---

## Ressources

**Fichiers clés à lire :**
- [fichier 1]
- [fichier 2]

**Documentation utile :**
- [lien 1]
- [lien 2]

---

## Notes

[Toute info additionnelle pertinente]
```

**Taille :** ~100 lignes

---

### 2. `tasks/done/TEMPLATE-report-simple.md`

**Pour tâches simples** (migration, tests, features simples)

```markdown
# Report: [Titre de la tâche]

**Task ID :** [TASK_ID]
**Type :** Bug Investigation | HAML Migration | Refactoring | Test Optimization | Feature
**Status :** ✅ Completed | ⚠️ Partial | ❌ Blocked
**Date :** YYYY-MM-DD
**Time Spent :** Xh Ymin
**Worktree :** worktree-[task-id]

---

## 📝 Résumé Exécutif

**En 3-5 lignes :**
- Ce qui a été fait
- Résultat final
- Tests status
- Points d'attention (si nécessaire)

**Exemple :**
✅ Migration de 3 fichiers HAML → ERB réussie
✅ Tests green (12 system specs passent)
✅ Accessibilité préservée (RGAA 4)
⚠️ Fichier dossiers/_complex.html.haml nécessite review manuelle

---

## 📊 Métriques

**Avant :**
- [métrique 1]
- [métrique 2]

**Après :**
- [métrique 1]
- [métrique 2]

**Gain :**
- [gain mesuré]

---

## 🔨 Changements Effectués

**Fichiers modifiés :**
1. `[fichier 1]` - [description changement]
2. `[fichier 2]` - [description changement]

**Commit :**
```bash
git log --oneline -1
[hash] [message]
```

---

## ✅ Tests

**Suite de tests lancée :**
```bash
bundle exec rspec [spec files]
XX examples, 0 failures
```

**Coverage :**
- Avant : XX%
- Après : XX%

---

## ⚠️ Points d'Attention

**Aucun**
OU
- [Point 1] - [explication]
- [Point 2] - [explication]

---

## 🚀 Prochaines Actions

**Aucune**
OU
- [ ] [Action 1] - Priorité: LOW/MEDIUM/HIGH

---

**Rapport généré le :** YYYY-MM-DD HH:MM
```

**Taille :** ~150 lignes

---

### 3. `tasks/done/TEMPLATE-report-investigation.md`

**Pour investigations complexes** (bugs, refacto)

**Sections supplémentaires :**
- Root Cause Analysis détaillée
- Solutions évaluées (2-3 approches avec pros/cons)
- Choix justifié
- Code avant/après (snippets)
- Impact & Risques
- Confidence Score (% que le fix résout le problème)

**Taille :** ~300 lignes

**Voir SPEC-archive.md section 4.3 pour template complet**

---

## 🛠️ Script `bin/launch-night-task`

### Objectif

Lancer Claude sur une tâche dans un worktree isolé en mode supervision minimale

### Usage

```bash
# Lancer 1 tâche
bin/launch-night-task bug-sentry-123

# Lancer plusieurs tâches (parallèle)
bin/launch-night-task bug-sentry-123 &
bin/launch-night-task migrate-haml-12 &
bin/launch-night-task refacto-42 &
```

### Fonctionnement

**Étapes exécutées :**

1. **Validation**
   - Vérifier que `.claude/tasks/queue/[TASK_ID].md` existe
   - Créer dossiers si nécessaire

2. **Setup Worktree**
   ```bash
   git worktree add ../worktrees/worktree-[TASK_ID] main
   ```

3. **Move Task**
   ```bash
   mv .claude/tasks/queue/[TASK_ID].md .claude/tasks/in-progress/
   ```

4. **Construire Prompt**
   ```markdown
   # Tu es un agent autonome

   ## Étape 1 : Lire le Contexte
   Lis TOUS les fichiers : .claude/context/*.md

   ## Étape 2 : Lire la Tâche
   Lis : .claude/tasks/in-progress/[TASK_ID].md

   ## Étape 3 : Identifier le Type
   Identifie le type de tâche (Bug | Migration | Refacto | Tests | Feature)

   ## Étape 4 : Lire le Prompt Template
   Lis le prompt template correspondant dans .claude/prompts/

   ## Étape 5 : Exécuter
   Suis les instructions du prompt template

   ## Étape 6 : Rapport
   Écris le rapport final dans .claude/tasks/done/[TASK_ID]-report.md

   IMPORTANT :
   - Respecte les actions pré-approuvées
   - Écris un rapport détaillé
   - Commit tes changements
   - Si bloqué : rapport partiel + explication
   ```

5. **Lancer Claude**
   ```bash
   cd ../worktrees/worktree-[TASK_ID]
   claude < /tmp/prompt-[TASK_ID].md
   ```

6. **Logger**
   ```bash
   echo "$(date) - START - Task: [TASK_ID]" >> .claude/logs/[TASK_ID].log
   ```

### Implémentation

**Fichier :** `bin/launch-night-task`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Configuration
CLAUDE_DIR=".claude"
TASKS_QUEUE="$CLAUDE_DIR/tasks/queue"
TASKS_IN_PROGRESS="$CLAUDE_DIR/tasks/in-progress"
LOGS_DIR="$CLAUDE_DIR/logs"
WORKTREES_BASE="../worktrees"

# Vérifier arguments
if [ $# -ne 1 ]; then
  echo "Usage: bin/launch-night-task TASK_ID"
  exit 1
fi

TASK_ID="$1"
TASK_FILE="$TASKS_QUEUE/$TASK_ID.md"
WORKTREE_NAME="worktree-$TASK_ID"
WORKTREE_PATH="$WORKTREES_BASE/$WORKTREE_NAME"
LOG_FILE="$LOGS_DIR/$TASK_ID-$(date +%Y%m%d-%H%M%S).log"

# Vérifier que la tâche existe
if [ ! -f "$TASK_FILE" ]; then
  echo "❌ Tâche introuvable: $TASK_FILE"
  exit 1
fi

# Créer dossiers
mkdir -p "$WORKTREES_BASE" "$LOGS_DIR" "$TASKS_IN_PROGRESS"

# Logger début
echo "$(date '+%Y-%m-%d %H:%M:%S') - START - Task: $TASK_ID" >> "$LOG_FILE"

# 1. Créer worktree
echo "📂 Création du worktree: $WORKTREE_NAME"
if [ -d "$WORKTREE_PATH" ]; then
  git worktree remove "$WORKTREE_NAME" 2>/dev/null || true
  rm -rf "$WORKTREE_PATH"
fi
git worktree add "$WORKTREE_PATH" main >> "$LOG_FILE" 2>&1

# 2. Déplacer tâche
mv "$TASK_FILE" "$TASKS_IN_PROGRESS/"

# 3. Construire le prompt
PROMPT=$(cat <<EOF
# Contexte de la Tâche

Tu es un agent autonome travaillant dans un worktree isolé.

## Étape 1 : Lire le Contexte
Lis TOUS les fichiers de contexte :
- .claude/context/project-overview.md
- .claude/context/code-preferences.md
- .claude/context/pre-approved-actions.md
- .claude/context/critical-constraints.md
- .claude/context/common-pitfalls.md

## Étape 2 : Lire la Tâche
Lis : .claude/tasks/in-progress/$TASK_ID.md

## Étape 3 : Identifier le Type
Identifie le type de tâche (Bug | Migration | Refacto | Tests | Feature)

## Étape 4 : Lire le Prompt Template
Lis le prompt template correspondant dans .claude/prompts/

## Étape 5 : Exécuter
Suis les instructions du prompt template

## Étape 6 : Rapport
Écris le rapport final dans .claude/tasks/done/$TASK_ID-report.md

IMPORTANT :
- Respecte les actions pré-approuvées
- Écris un rapport détaillé
- Commit tes changements
- Si bloqué : rapport partiel + explication
EOF
)

# 4. Sauver prompt
PROMPT_FILE="/tmp/claude-prompt-$TASK_ID.md"
echo "$PROMPT" > "$PROMPT_FILE"

echo ""
echo "✅ Setup terminé !"
echo ""
echo "📁 Worktree : $WORKTREE_PATH"
echo "📝 Prompt : $PROMPT_FILE"
echo "📊 Logs : $LOG_FILE"
echo ""
echo "Lance Claude avec :"
echo "  cd $WORKTREE_PATH && claude"
echo ""
echo "Puis copie/colle le contenu de: $PROMPT_FILE"
```

**Permissions :**
```bash
chmod +x bin/launch-night-task
```

### Alternative : macOS Terminal Auto-open

```bash
# À la fin du script, ajouter :
if [[ "$OSTYPE" == "darwin"* ]]; then
  osascript <<EOF
    tell application "Terminal"
      do script "cd $WORKTREE_PATH && cat $PROMPT_FILE && echo '' && claude"
      activate
    end tell
EOF
fi
```

---

## 🔄 Script `bin/review-task` (Phase 2)

### Objectif

Faciliter la review d'une tâche terminée

### Usage

```bash
bin/review-task bug-sentry-123
```

### Fonctionnement

1. Afficher rapport : `cat .claude/tasks/done/bug-123-report.md`
2. Afficher diff : `cd worktree-bug-123 && git diff main`
3. Proposer actions :
   - `m` : merge
   - `r` : reject (cleanup worktree)
   - `v` : view in editor
   - `t` : run tests
   - `q` : quit

**Implémentation :** Phase 2 (après validation workflow)

---

## ✅ Critères d'Acceptance

### Epic 2 Complet

- [ ] 3 templates créés (task queue, report simple, report investigation)
- [ ] Script `bin/launch-night-task` fonctionnel
- [ ] Tests manuels : lancer 1 tâche de bout en bout
- [ ] Logs générés correctement
- [ ] Documentation claire (ce fichier)

### Workflow Validé

- [ ] Créer tâche dans queue/ : < 5min
- [ ] Lancer script : fonctionne sans erreur
- [ ] Claude démarre avec prompt structuré
- [ ] Rapport généré dans done/
- [ ] Review rapport : < 5min

---

## 📊 Métriques de Succès

**Temps de setup :**
- Créer tâche : < 5min
- Lancer script : < 30s
- Review rapport : < 5min
- **Total overhead : < 10min par tâche**

**Qualité rapports :**
- Lisibles en < 5min : 100%
- Décision merge/reject évidente : > 80%
- Informations manquantes : < 20%

---

## 🎯 Prochaines Étapes

**Après Epic 2 :**
→ Epic 3 : Créer les 5 prompts templates (utiliseront les templates de rapports)

**Phase 2 (si success) :**
→ Script `bin/review-task` interactif
→ Script `bin/review-reports` (agréger plusieurs rapports)
→ Amélioration logging (durée, success rate, etc.)

---

*Epic 2 v1.0 - 2026-03-08*
