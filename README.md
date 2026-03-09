# Night Shift - Pipelines de développement avec IA

**Statut :** Démonstrateur - Apprentissage en cours
**Dernière mise à jour :** 2026-03-09

---

## 💡 L'idée

### Le problème

Développer sur des projets complexes, c'est :
- Des milliers de fichiers à gérer
- Des dizaines de règles à respecter (accessibilité, sécurité, performance)
- Des tâches répétitives mais qui demandent de l'attention
- Une charge mentale constante

**Résultat :** On fait tout à la main, on n'arrive pas à déléguer, on est surchargé.

### La question

Maintenant qu'on a des agents IA (Claude, GPT-4, etc.), on se demande :

**Peut-on leur déléguer certaines tâches répétitives ?**

Pas tout automatiser d'un coup. Juste :
- Identifier les tâches qu'on fait souvent
- Voir si l'IA peut les gérer de façon autonome
- Apprendre ce qui marche et ce qui ne marche pas
- Améliorer petit à petit

---

## 🎯 Notre approche

### ❌ Ce qu'on ne fait PAS

**Le prompt géant :**
- Créer un prompt de 2000 lignes qui couvre tous les cas
- Espérer que ça marche du premier coup
- Résultat : trop complexe, ça échoue

**La solution universelle :**
- Un seul pipeline pour tous les projets
- Automatisation maximale sans adaptation
- Résultat : ne marche sur aucun projet réel

### ✅ Ce qu'on fait

**Petits pas itératifs, adapté à VOTRE projet :**

1. **Commencer simple**
   - Choisir UNE tâche répétitive
   - Créer un prompt basique
   - Tester sur quelques fichiers

2. **Observer et apprendre**
   - Qu'est-ce qui marche ?
   - Qu'est-ce qui coince ?
   - Quelles erreurs se répètent ?

3. **Améliorer**
   - Documenter les erreurs trouvées
   - Enrichir le prompt avec ce qu'on a appris
   - Retester pour voir si c'est mieux

4. **Répéter**
   - Continuer à améliorer jusqu'à avoir confiance
   - Puis passer à une autre tâche

**L'important :** Pas le succès immédiat, mais la capacité à apprendre et progresser.

---

## 🔬 Ce projet

### Ce que c'est

- Un **démonstrateur** pour montrer la méthode
- Une **documentation** de ce qui marche (et de ce qui échoue)
- Un **terrain d'expérimentation** pour apprendre

### Ce que ce n'est pas

- ❌ Un outil clé en main
- ❌ Une solution magique
- ❌ Un succès garanti

---

## 🧪 Projet exemple : demarche.numerique.gouv.fr

**Contexte**
- Application Rails, ~30 000 commits
- Beaucoup de code legacy (HAML à migrer vers ERB)
- Contraintes fortes : accessibilité (RGAA), sécurité, API GraphQL

**Tâches répétitives identifiées**
- Migrer des fichiers HAML vers ERB
- Corriger des bugs récurrents
- Optimiser des tests lents
- Développer des petites features simples

**Question** : L'IA peut-elle gérer ces tâches de façon autonome ?

---

## 📐 Méthode

### Phase 0 : Identifier la complexité

**Votre projet est unique.** Avant de construire un pipeline, comprendre :

**1. Les tâches répétitives**
- Quelles tâches reviennent souvent ?
- Lesquelles sont mécaniques mais chronophages ?
- Lesquelles génèrent de la charge mentale ?

**2. Les règles et contraintes**
- Quels patterns techniques sont critiques ?
- Quelles contraintes sont non-négociables ?
- Quels sont les pièges récurrents ?

**3. L'infrastructure**
- Comment isoler le travail de l'agent ? (branches, worktrees)
- Comment valider sans risque ? (tests, linters)
- Comment annuler facilement ?

**Sur notre exemple :**
- 4 types de tâches : HAML→ERB, tests lents, bugs Sentry, features simples
- Contraintes : RGAA 4, sécurité étatique
- Infrastructure : git worktrees isolés

---

### Phase 1 : Tester sur 1 tâche

**Objectif :** Voir si un agent IA peut gérer 1 type de tâche

**Approche par petits pas :**

1. **Choisir 1 tâche** (ex: migrer HAML→ERB)
2. **Créer un prompt simple** (juste la conversion de base)
3. **Tester sur un petit batch** (5-12 fichiers)
4. **Observer** (qu'est-ce qui marche ? qu'est-ce qui coince ?)
5. **Documenter** (noter les erreurs, les patterns)
6. **Améliorer** (enrichir le prompt avec ce qu'on a appris)
7. **Réitérer** jusqu'à avoir confiance

**Questions à tester :**
- L'agent peut-il faire ça tout seul ?
- Avec un prompt simple, on arrive à quel niveau de qualité ?
- Le temps investi vaut-il le coup ?

**Critères de réussite :**
- Charge mentale réduite (puis-je partir faire autre chose ?)
- Qualité acceptable (tests passent, pas de bug)
- Learnings capturés (documentation pour s'améliorer)

**Si ça échoue, c'est OK** → On apprend ce qui manque et on améliore

---

### Phase 2 : Affiner et étendre

Si Phase 1 montre que c'est viable :
- Identifier ce qui bloque encore
- Améliorer sur ces points précis
- Tester un 2ème type de tâche
- Mesurer si le temps gagné justifie le temps investi

---

### Phase 3 : Extraire la méthode

Si ça marche bien sur plusieurs tâches :
- Documenter ce qui a marché (et pourquoi)
- Documenter ce qui n'a pas marché (et pourquoi)
- Extraire une méthode réutilisable sur d'autres projets

---

## 🏗️ Organisation du projet

```
night-shift/
├── README.md              # Ce fichier
├── WORKFLOW.md            # Guide pratique (comment lancer un POC)
├── essentials.md          # Base de connaissances (patterns découverts)
│
├── pocs/                  # Expérimentations
│   ├── 1-haml/            # POC migration HAML→ERB
│   ├── 2-tests/           # POC optimisation tests
│   ├── 3-bugs/            # POC correction bugs
│   └── 4-features/        # POC petites features
│
├── kaizen/                # Documentation des apprentissages
│   ├── templates/         # Templates pour documenter
│   └── poc-*/             # Learnings par POC (à venir)
│
└── .claude/
    └── prompts/           # Prompts pour lancer les agents
```

**Note :** `essentials.md` et les prompts évoluent au fur et à mesure qu'on apprend.

---

## 📖 Documentation

- `README.md` : Vision et méthode (ce fichier)
- `WORKFLOW.md` : Guide pratique (comment lancer un POC, comment documenter)
- `essentials.md` : Base de connaissances (patterns découverts, évolutif)
- `pocs/*/setup.md` : Setup détaillé par POC
- `kaizen/templates/` : Templates pour documenter les apprentissages

---

## 🎯 Philosophie

### Ce projet réussit si :

- ✅ On apprend à identifier la complexité d'un projet
- ✅ On construit une méthode reproductible
- ✅ On documente nos échecs ET nos réussites
- ✅ On réduit la charge mentale (même modestement)

### Ce projet échoue si :

- ❌ On cherche la solution parfaite du premier coup
- ❌ On crée des prompts de 2000 lignes trop complexes
- ❌ On ne documente pas ce qu'on apprend
- ❌ On abandonne au premier obstacle

**L'échec fait partie du processus. Ce qui compte, c'est d'apprendre.**

---

*Night Shift - Démonstrateur d'apprentissage*
*Construire des pipelines de dev adaptés à VOTRE projet*

**On ne construit pas un outil, on apprend à construire des pipelines. L'échec fait partie du processus.**
