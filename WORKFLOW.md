# Workflow POC - Guide Pratique

**Mise à jour :** 2026-03-09

Ce guide explique **concrètement** comment lancer un POC et documenter les learnings.

---

## 🚀 Workflow Complet POC 1 (HAML Migration)

### Étape 1 : Lancer le POC (2min)

```bash
# 1. Aller dans le worktree POC 1
cd /Users/mfo/dev/demarche.numerique.gouv.fr-poc-haml

# 2. Lancer Claude
claude

# 3. Utiliser le slash command
/haml-migrate app/views/release_notes/_announce.html.haml
```

**Alternative manuelle :**
```bash
# Copier le prompt
cat ~/dev/night-shift/pocs/1-haml/setup.md
# Lignes 53-197 → Coller dans Claude
```

### Étape 2 : Observer (30-45min)

**Règles :**
- ✅ Laisse Claude travailler
- ✅ Note l'heure de début
- ✅ Observe les questions posées
- ❌ N'interviens que si bloqué > 15min

**Pendant l'exécution, note :**
- Questions posées (nombre + nature)
- Blocages rencontrés (quand + pourquoi)
- Interventions nécessaires (combien + lesquelles)

### Étape 3 : Documenter Results (10min)

**Immédiatement après la fin du POC :**

```bash
# Dans le worktree POC 1
/results
```

Ce slash command :
1. Lit le template `pocs/1-haml/results.md`
2. Le remplit avec les VRAIES données de cette session
3. Sauvegarde dans `pocs/1-haml/results.md`

**Ou manuellement :**
```bash
cd ~/dev/night-shift/pocs/1-haml/
# Éditer results.md avec les vraies données
```

### Étape 4 : Kaizen (10min)

**Documenter les learnings pour amélioration continue :**

```bash
# Dans le worktree POC 1
/kaizen
```

Ce slash command :
1. Lit le template `kaizen/templates/task.md`
2. Crée `pocs/1-haml/kaizen-2026-03-09.md`
3. Guide pour remplir toutes les sections

**Focus kaizen :**
- Ce qui a bien marché → à réutiliser
- Ce qui a coincé → à améliorer
- Agent-friendly score → est-ce vraiment fire-and-forget ?
- Améliorations concrètes → essentials.md v2 ? prompt v1.1 ?

### Étape 5 : Décision (5min)

**Basé sur le score POC 1 :**

**Si score ≥ 4/5 :**
```bash
# Préparer POC 2
cd ~/dev/night-shift
cat pocs/overview.md  # Lire planning Semaine 1
# Décider : lancer POC 2 cette semaine ?
```

**Si score 3/5 :**
```bash
# Itérer sur POC 1
# 1. Lire kaizen-2026-03-09.md
# 2. Améliorer essentials.md ou prompt
# 3. Retry POC 1 sur un autre fichier HAML
# 4. Comparer v1 vs v2
```

**Si score ≤ 2/5 :**
```bash
# Analyser causes d'échec
# 1. Lire results.md + kaizen.md
# 2. Identifier : problème prompt ? contexte ? hypothèse ?
# 3. Décider : pivoter ou itérer ?
```

---

## 🔄 Capitaliser les Learnings (Démarche Kaizen → Commit)

### Objectif

Transformer le kaizen en commit qui raconte l'histoire de l'évolution du pipeline. Le git log doit être **une histoire fluide**, pas une suite de commits aléatoires.

### Workflow Kaizen → Commit

**Contexte :** Tu viens de terminer Phase 1.1 avec un kaizen documenté.

#### 1. Revenir dans le repo night-shift

```bash
cd ~/dev/night-shift
```

#### 2. Lancer Claude avec le contexte kaizen

```bash
claude
```

**Prompt Claude :**
```markdown
Je viens de terminer un POC avec les résultats suivants :

[Copier le contenu du kaizen]

Voici ce qu'on doit faire maintenant :

1. Lire le kaizen et identifier les learnings critiques
2. Enrichir `essentials.md` avec les patterns découverts
3. Améliorer `.claude/prompts/haml-migration.md` en intégrant ces learnings
4. Préparer un commit qui raconte l'évolution

Le commit doit montrer :
- Ce qui a échoué (résultats)
- Ce qu'on a appris (kaizen)
- Ce qu'on améliore (prompt + essentials)

Structure git story :
- Commit précédent : Hypothèse ("Un agent peut-il migrer HAML ?")
- Ce commit : Résultats + Learnings + Améliorations
- Commit suivant : Validation avec prompt amélioré
```

#### 3. Workflow automatique avec Claude

Claude va :
1. **Lire** le kaizen complet
2. **Analyser** les erreurs et patterns
3. **Enrichir** `essentials.md` avec :
   - Patterns critiques découverts
   - Commandes utiles identifiées
   - Checklist validation manquante
4. **Améliorer** le prompt avec :
   - Règles de conversion manquantes
   - Checkpoints validation locale
   - Temps ajustés
5. **Proposer** un message de commit qui raconte l'histoire

#### 4. Valider et commit

```bash
# Claude propose :
# - Les changements à essentials.md
# - Les changements au prompt
# - Un message de commit clair

# Tu valides et commit
git add essentials.md .claude/prompts/haml-migration.md kaizen/poc-haml-migration/
git commit -m "[message proposé par Claude]"
```

---

### Template Prompt pour Claude

**Copier ce template quand tu veux capitaliser un kaizen :**

```markdown
# Contexte
Je travaille sur Night Shift, un pipeline Toyotiste pour dev logiciel.
Le ground 0 pose une hypothèse : "Un agent IA peut-il migrer HAML→ERB ?"

# Kaizen Phase 1.1
[Coller le contenu complet du kaizen ici]

# Tâche
1. Lire ce kaizen et identifier les 3-5 learnings critiques
2. Enrichir `essentials.md` :
   - Ajouter patterns HAML→ERB découverts
   - Ajouter commandes utiles (linter, tests)
   - Ajouter checklist validation locale
3. Améliorer `.claude/prompts/haml-migration.md` :
   - Intégrer les règles manquantes
   - Ajouter checkpoint validation locale
   - Ajuster temps estimés
4. Déplacer le kaizen dans `kaizen/poc-haml-migration/[date].md`
5. Proposer un message de commit qui raconte l'histoire :
   - Résultats Phase 1.1 (X erreurs, score Y/10)
   - Learnings (patterns critiques)
   - Améliorations (prompt + essentials)
   - Hypothèse suivante (re-test avec prompt amélioré)

# Contrainte
Le commit doit être **auto-portant** : quelqu'un qui lit juste le git log doit comprendre l'évolution.

# Livrable
- essentials.md enrichi
- prompt amélioré
- kaizen déplacé
- message de commit proposé
```

---

### Exemple Git Story

**Commit 1 (ground 0) :**
```
init(night-shift): first POC of night-shift

Hypothèse : Un agent IA peut-il migrer HAML→ERB de façon autonome ?
```

**Commit 2 (kaizen) :**
```
docs(kaizen): Phase 1.1 results + learnings

Phase 1.1: 12 fichiers migrés, 4 erreurs critiques découvertes
- Arrays non joints (HAML auto-join, ERB non)
- Balises auto-fermantes (HTML5 interdit)
- Espacement (ERB préserve, HAML compacte)
- Validation locale absente (23min CI perdues)

Améliorations:
- essentials.md: patterns HAML→ERB critiques
- prompt: validation locale + règles complètes

Hypothèse invalidée: fire-and-forget impossible sans validation
Prochaine étape: tester prompt amélioré (target: 8/10)
```

**Commit 3 (validation) :**
```
feat(prompt): validate improved prompt on Phase 1.2

Test prompt v1.1 sur 5 fichiers
Résultats: 0 erreur CI, 1 warning local catchée
Score: 8/10 (oneshot pratique atteint)

Hypothèse validée: prompt enrichi permet oneshot pratique
```

---

## 📋 Checklist POC Complet

### Avant de Lancer
- [ ] Worktree créé
- [ ] essentials.md à jour
- [ ] Prompt prêt (slash command ou manuel)
- [ ] Chronomètre prêt

### Pendant le POC
- [ ] Heure début notée
- [ ] Questions posées notées
- [ ] Blocages observés
- [ ] Interventions minimales

### Après le POC
- [ ] results.md rempli avec vraies données
- [ ] kaizen-YYYY-MM-DD.md créé
- [ ] Score calculé (X/5)
- [ ] Décision prise (continuer/itérer/pivoter)

### Amélioration Continue
- [ ] essentials.md mis à jour si pattern récurrent
- [ ] Prompt versionné (v1.1) si améliorations
- [ ] Commit des changements

---

## 🎯 Slash Commands Disponibles

**Dans le worktree POC 1 :**

### `/haml-migrate [fichier]`
Lance la migration HAML→ERB d'un fichier.

**Usage :**
```bash
/haml-migrate app/views/release_notes/_announce.html.haml
```

**Ce qu'il fait :**
- Lit essentials.md
- Suit le prompt haml-migration.md
- Migre le fichier
- Génère rapport

### `/results`
Génère le rapport results.md après le POC.

**Usage :**
```bash
/results
```

**Ce qu'il fait :**
- Lit template pocs/1-haml/results.md
- Remplit avec vraies données de cette session
- Sauvegarde results.md

### `/kaizen`
Crée le kaizen de cette tâche.

**Usage :**
```bash
/kaizen
```

**Ce qu'il fait :**
- Lit template kaizen/templates/task.md
- Crée pocs/1-haml/kaizen-YYYY-MM-DD.md
- Guide pour documenter learnings

---

## 📊 Exemples Concrets

### Exemple Session Réussie (Score 5/5)

```
14:23 - Lancer /haml-migrate _announce.html.haml
14:25 - Claude démarre (lecture fichier)
14:30 - Cherche tests (aucun trouvé)
14:35 - Conversion HAML→ERB
14:50 - Vérification diff
14:55 - Commit
15:00 - Rapport généré
15:05 - /results (10min pour remplir)
15:15 - /kaizen (10min pour documenter)

Durée totale : 42min POC + 20min doc = 62min
Score : 5/5 (aucune intervention, fire-and-forget total)
```

### Exemple Session Partiellement Réussie (Score 3/5)

```
10:15 - Lancer /haml-migrate _card.html.haml
10:17 - Claude démarre
10:25 - Question : "Dois-je supprimer HAML ?" (intervention)
10:30 - Continue conversion
10:45 - Tests échouent (intervention - debug ensemble)
11:00 - Fix attribut data manquant
11:10 - Tests passent
11:15 - Commit
11:20 - /results
11:30 - /kaizen

Durée : 65min POC + 10min doc = 75min
Score : 3/5 (2 interventions, temps dépassé)
Learnings : Clarifier workflow suppression, améliorer règles data-*
```

---

## 🔄 Amélioration Continue (Kaizen Loop)

```
POC 1 (v1.0)
    ↓
results.md + kaizen.md
    ↓
Identify improvements
    ↓
essentials.md v1.1
prompt haml-migration.md v1.1
    ↓
POC 1 retry (v1.1)
    ↓
Compare v1.0 vs v1.1
    ↓
If better → Keep v1.1
If worse → Rollback or v1.2
```

**Critère de succès kaizen :**
Le v1.1 doit avoir un score ≥ v1.0 + 1 point.

---

## 💡 Tips

### Pour Maximiser Fire-and-Forget

1. **Essentials.md clair** : Plus c'est clair, moins de questions
2. **Prompt détaillé** : Exemples concrets > instructions vagues
3. **Checkpoints** : 15min, 30min → Claude s'auto-vérifie
4. **Actions pré-approuvées** : Liste exhaustive → pas de demande permission

### Pour Bons Kaizen

1. **Immédiatement après** : Ne pas attendre (oubli)
2. **Honnêteté** : Échec = matériau précieux
3. **Concret** : "Ajouter X ligne 42" > "Améliorer contexte"
4. **Actionnable** : Checkbox claire pour prochaine fois

### Pour Itérer Efficacement

1. **1 changement à la fois** : v1.0 → v1.1 (pas v2.0)
2. **Mesurer** : Score avant/après
3. **Documenter** : Pourquoi ce changement ?
4. **Comparer** : v1.1 meilleur que v1.0 ?

---

**Principe :** Ce workflow devient plus fluide à chaque itération. La première fois prend 90min, la 5ème fois prend 50min.
