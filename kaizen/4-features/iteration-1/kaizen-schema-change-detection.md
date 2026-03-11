# Kaizen - Session 3 : Feature Simpliscore (Schema Change Detection)

**Date :** 2026-03-10
**Proposé par :** Agent Claude + Humain (collaboration)
**Contexte :** Implémentation commit 17 du refactoring tunnel_id - Cleanup & schema change detection

---

## 🎯 Problème Identifié

**Situation observée :**
Session de continuation après limite de contexte. Travail sur cleanup de refactoring majeur (commits 1-16) + bugs découverts + nouvelle feature (schema change detection).

**Type de session :**
- ✅ Feature complexe multi-composants (model + controller + job + query + migration + 73 tests)
- ✅ Debugging de bugs découverts en production simulée
- ✅ Workflow itératif avec feedback utilisateur continu

**Complexité :**
- 10 fichiers modifiés (app + specs + migration)
- 176 insertions, 61 suppressions
- 3 bugs critiques découverts et corrigés
- 73 tests adaptés/réactivés/créés
- 1 migration DB avec suppression d'ancien index unique

---

## ✅ Ce Qui a Bien Fonctionné

### 1. TodoWrite pour tracking de progression

**Observation :**
Utilisation systématique de TodoWrite tout au long de la session pour tracker les tâches.

**Exemple :**
```
Phase 1-6: Commits 1-16 DONE ✅
Fix controller specs ✅
Implement schema change detection ✅
Adapt Groups 3-8 tests ✅
Fix component specs ✅
Add DB unique constraint ✅
```

**Impact :**
- ✅ Visibilité claire de la progression pour l'utilisateur
- ✅ Permet de reprendre facilement après interruption
- ✅ Aide à ne rien oublier (11 pending tests à traiter)

**Recommandation :**
**CONSERVER** - TodoWrite est essentiel pour features complexes multi-étapes.

---

### 2. Demander confirmation pour décisions architecturales

**Observation :**
Utilisateur a demandé : "c'est bien d'avoir ajouté le validates, mais il faut aussi revoir la migration non ?"

**Situation :**
J'avais ajouté la validation Rails `uniqueness: { scope: [:procedure_revision_id, :rule, :schema_hash] }` mais oublié de mettre à jour la contrainte DB.

**Résultat :**
- ✅ L'utilisateur a détecté l'incohérence
- ✅ Correction immédiate : migration pour supprimer ancien index et ajouter nouveau
- ✅ Cohérence entre code et DB garantie

**Pattern identifié :**
Quand on change une validation d'unicité, TOUJOURS vérifier s'il y a un index unique correspondant en DB.

**Impact :** Évite des erreurs silencieuses en production (test passerait mais prod crasherait).

---

### 3. Workflow itératif avec feedback continu

**Déroulement réel :**

1. **User :** "continue correcting tests after commit 17 cleanup"
2. **Claude :** Fixe 18 controller specs en échec
3. **User :** "le job ne s'enqueue pas quand je clique"
4. **Claude :** Debug → Fix condition dans ImproveProcedureJob
5. **User :** "le schema_hash est memoized, c'est un bug"
6. **Claude :** Fix current_schema_hash (supprime memoization)
7. **User :** "on veut pas revisiter étapes accepted/skipped"
8. **Claude :** Réécriture logique de redirection
9. **User :** "décidons 1 à 1 pour les pending tests"
10. **Claude :** Traite groupes 3-8, réactive/adapte tests
11. **User :** "peux-tu ajouter un test system pour schema change ?"
12. **Claude :** Crée test system complet validant le workflow

**Observations :**
- ✅ Bugs découverts progressivement, pas tous d'un coup
- ✅ Chaque fix est testé immédiatement
- ✅ User guide sur les décisions métier (comportement redirection)
- ✅ Claude gère l'implémentation technique

**Pattern réussi :**
```
User: Signale comportement attendu
  ↓
Claude: Implémente + adapte tests
  ↓
User: Valide ou corrige compréhension
  ↓
Claude: Ajuste
```

---

### 4. Tests comme documentation du comportement

**Observation :**
Les 73 tests corrigés documentent exactement les cas d'usage du schema change :

**Tests réactivés (Groupes 3-4) :**
```ruby
context 'when schema changes mid-tunnel after accepting step 1' do
  it 'allows accessing step 2 after schema changed'
  it 'creates step 2 suggestion with current schema_hash'
end
```

**Test system ajouté :**
```ruby
scenario 'allows regenerating suggestions when schema has changed' do
  # 1. Créer suggestion avec schema V1
  # 2. Changer schema → V2
  # 3. Visiter même étape → ne montre PAS V1
  # 4. Cliquer "Lancer recherche" → crée V2
  # 5. Vérifier coexistence V1 et V2
end
```

**Impact :**
- ✅ Tests servent de spécification vivante
- ✅ Régression impossible sans casser tests
- ✅ Comportement explicite et vérifiable

---

### 5. Commit message structuré et détaillé

**Commit final :**
```
fix(simpliscore): gestion du changement de schema en cours de tunnel

Permet la régénération des suggestions quand le schema change pendant un tunnel :
- Query par (tunnel_id, rule, schema_hash) au lieu de (tunnel_id, rule)
- L'utilisateur peut cliquer sur "Lancer la recherche" pour régénérer

Modifications principales :
- SimpliscoreConcern#simplify : query avec schema_hash
- [... 7 autres points clés ...]

Tests :
- 47 controller specs passent (adaptation Groupes 3-8)
- 25 component specs passent (tunnel_id requis)
- Nouveau test system validant régénération après schema change
- Total : 73 tests qui passent

🤖 Generated with [Claude Code]
Co-Authored-By: Claude <noreply@anthropic.com>
```

**Pourquoi c'est efficace :**
- ✅ Contexte business clair (pourquoi)
- ✅ Détails techniques structurés (quoi)
- ✅ Résultats tests quantifiés (validation)
- ✅ Traçabilité (nombre de tests)

**Pattern :** Commit message = mini-rapport de feature

---

## ⚠️ Ce Qui Pourrait Être Amélioré

### 1. Détection proactive des incohérences DB/validation

**Problème :**
J'ai ajouté `validates :tunnel_id, uniqueness: { scope: [..., :schema_hash] }` mais pas pensé à vérifier l'index DB correspondant.

**Coût :**
- User a dû le signaler
- 5 min perdues à corriger après coup

**Solution proposée :**
Quand je modifie une validation `uniqueness`, ajouter automatiquement un checkpoint :

```markdown
## Checkpoint Validation Uniqueness

**Quand tu ajoutes/modifies `validates :field, uniqueness: { scope: [...] }` :**

1. ✅ Cherche index unique correspondant en DB :
   ```bash
   grep -r "add_index.*unique: true" db/migrate/
   # ou
   cat db/schema.rb | grep -A3 "unique: true"
   ```

2. ✅ Vérifie cohérence :
   - Validation Rails scope: `[:field_a, :field_b, :field_c]`
   - Index DB: `add_index :table, [:field_a, :field_b, :field_c], unique: true`

3. ⚠️ Si incohérence détectée → créer migration pour :
   - Supprimer ancien index unique (si exists)
   - Ajouter nouveau index unique cohérent

**Pourquoi c'est important :**
- Tests passent avec validation Rails seule
- Mais production crashe si DB rejette (PG::UniqueViolation)
- Détection précoce = 0 surprise en prod
```

**Type d'amélioration :** Nouveau checkpoint

**Impact estimé :**
- Fréquence : 1 fois sur 20 features (validation uniqueness peu fréquente)
- Temps gagné : 5-10 min par occurrence
- Risque évité : ÉLEVÉ (crash production)

---

### 2. Pattern "Read-Then-Edit" pas toujours respecté

**Problème observé :**
À plusieurs reprises, j'ai eu l'erreur :
```
<tool_use_error>File has been modified since read, either by the user or by a linter.
Read it again before attempting to write it.</tool_use_error>
```

**Cause :**
1. Je lis un fichier
2. Linter auto-format le fichier (ex: Rubocop)
3. J'essaie d'éditer → erreur car checksum changé

**Solution actuelle :** Re-lire puis éditer

**Amélioration proposée :**
Avant CHAQUE Edit, vérifier si le fichier a été modifié récemment (< 5 sec) :

```markdown
## Pattern Edit Robuste

**Avant chaque Edit :**

1. ✅ Si fichier pas encore lu dans cette session → Read d'abord
2. ✅ Si dernier Read > 30 sec → Re-read par sécurité
3. ✅ Si Edit échoue avec "file modified" → Re-read + retry (1 fois)

**Cas particulier : Linters auto-format**
- Rubocop, prettier, etc. peuvent modifier le fichier juste après écriture
- Si Edit échoue → Re-read systématiquement, ne pas insister
```

**Type d'amélioration :** Clarification existante (process d'édition)

**Impact :**
- Fréquence : 2-3 fois par session longue
- Temps perdu : ~1 min par retry
- Solution : Simple Re-read, pas bloquant

---

### 3. Gestion des tests pending : décision 1 à 1 chronophage

**Situation :**
11 tests pending après cleanup. User voulait décider 1 à 1 lesquels garder/adapter/supprimer.

**Déroulement réel :**
- Groupes 1-2 : ADAPTER (3 tests)
- Groupes 3-8 : User demande pause → manque de contexte → sauvegarde dans fichier

**Temps :**
- Lister et grouper tests : 10 min
- Décider groupe 1 : 5 min
- Décider groupe 2 : 5 min
- Créer TESTS_REMAINING_TODO.md : 5 min
- **Total : 25 min** pour traiter 3 tests sur 11

**Projection :** 25 min × (11/3) ≈ **90 min** pour traiter tous les tests

**Amélioration proposée :**

```markdown
## Pattern Triage Tests Pending

**Quand > 5 tests pending après refactoring :**

1. ✅ Grouper par similarité (ex: même context, même règle testée)

2. ✅ Proposer décision par groupe :
   - **ADAPTER** : comportement a changé mais test reste valide
   - **SUPPRIMER** : test obsolète (feature retirée)
   - **GARDER PENDING** : décision ultérieure (pas bloquant)

3. ✅ Présenter 3 groupes MAX à la fois (avoid overwhelm)
   - Groupe 1 : [X tests] - Proposition : ADAPTER - Raison : [...]
   - Groupe 2 : [Y tests] - Proposition : SUPPRIMER - Raison : [...]
   - Groupe 3 : [Z tests] - Proposition : GARDER PENDING - Raison : [...]

4. ⚠️ Si user demande pause → sauvegarder état dans fichier markdown :
   - Tests traités (avec décisions)
   - Tests restants (avec propositions)
   - Permet reprise facile

**Time budget :** 5 min par groupe de tests (max 3 groupes/itération)
```

**Type d'amélioration :** Nouveau pattern pré-approuvé

**Impact estimé :**
- Fréquence : 1 fois par 10 features (refactoring majeur rare)
- Temps gagné : 30-40 min (évite back-and-forth)
- Charge mentale : MOYENNE → FAIBLE

---

### 4. Documentation en cours de session vs. post-session

**Observation :**
J'ai créé 2 logs durant la session :
1. `TESTS_REMAINING_TODO.md` - État intermédiaire pour reprendre après pause
2. `log-simpliscore-implementation-3.md` - Rapport complet post-session

**Ce qui a bien marché :**
- ✅ TESTS_REMAINING_TODO.md sauvé avant limite contexte
- ✅ Permet de reprendre exactement où on était
- ✅ Format markdown structuré, facile à parser

**Amélioration :**
Systématiser la documentation intermédiaire pour sessions longues.

```markdown
## Pattern Session Longue (> 2h)

**Checkpoint à mi-session (~1h30) :**

1. ✅ Créer fichier `SESSION-CHECKPOINT-[timestamp].md` :
   ```markdown
   # Session Checkpoint

   ## Objectif session
   [Rappel de l'objectif initial]

   ## Progression
   - [x] Tâche 1 ✅
   - [x] Tâche 2 ✅
   - [ ] Tâche 3 (en cours)
   - [ ] Tâche 4 (pending)

   ## État actuel
   - Tests passent : X/Y
   - Fichiers modifiés : [liste]
   - Bugs découverts : [liste]

   ## Décisions prises
   1. [Décision 1 avec raison]
   2. [Décision 2 avec raison]

   ## Next steps
   1. [Prochaine action]
   2. [Puis celle-ci]
   ```

2. ✅ Permet à user de :
   - Valider progression
   - Corriger direction si nécessaire
   - Prendre pause sans perte contexte

**Quand utiliser :**
- Session > 2h
- > 5 fichiers modifiés
- > 3 décisions architecturales prises
```

**Type d'amélioration :** Nouveau checkpoint

---

## 📊 Impact Global de la Session

### Métriques de Réussite

**Objectif atteint :** ✅ Commit 17 complété avec schema change detection

**Livrables :**
- ✅ 3 bugs critiques corrigés
- ✅ Feature schema change detection implémentée
- ✅ 73 tests passent (47 controller + 25 component + 1 system)
- ✅ Migration DB cohérente avec validation Rails
- ✅ Documentation exhaustive (log-simpliscore-implementation-3.md)

**Temps total :** ~3h30
- Debugging bugs : 45 min
- Implémentation schema detection : 60 min
- Adaptation tests : 90 min
- Migration DB : 20 min
- Documentation : 15 min

**Qualité :**
- ✅ 0 régression
- ✅ Coverage maintenu
- ✅ Commit mergeable tel quel

---

### Charge Mentale User vs. Agent

**Ce que l'agent a géré seul :**
- ✅ Implémentation technique (query, job, controller, query object)
- ✅ Adaptation de 73 tests (lecture, compréhension, modification)
- ✅ Création migration DB avec up/down
- ✅ Rédaction documentation complète
- ✅ Tracking progression (TodoWrite)

**Ce que le user a dû gérer :**
- ⚠️ Détection bugs (job non enqueued, memoization)
- ⚠️ Décisions métier (comportement redirection)
- ⚠️ Validation cohérence DB/validation
- ⚠️ Demande test system supplémentaire

**Ratio autonomie :** ~70% agent / 30% user

**Analyse :**
- ✅ Agent gère bien l'implémentation technique
- ⚠️ User doit rester vigilant sur bugs et cohérence
- ✅ Collaboration efficace (pas de blocage > 30 min)

---

## 💡 Learnings pour Future Sessions

### 1. Sur le Projet (demarches-simplifiees.fr)

**Pattern découvert : Schema Change pendant refactoring**
- Refactoring majeur (tunnel_id) → besoin de gérer évolution schema
- Solution : Query par `(clé_métier, schema_hash)` au lieu de `(clé_métier)`
- Permet coexistence versions anciennes/nouvelles
- Nécessite index unique composite

**Réutilisable pour :**
- Autres refactorings majeurs sur features à état
- Migration progressive de schéma
- Versioning de données métier

---

### 2. Sur l'Agent-Friendliness

**Ce qui aide Claude à être autonome :**

✅ **Todo list structurée**
- Grouper tests similaires (Groupes 1-8)
- Permet de batching decisions
- Réduit back-and-forth

✅ **Tests comme specs**
- Tests pending = documentation de comportement attendu
- Adapter test = comprendre nouveau comportement
- Coverage = validation complétude

✅ **Feedback immédiat**
- User signale bug → Claude debug immédiatement
- Pas d'accumulation de bugs non détectés

⚠️ **Ce qui crée friction :**
- Décisions 1 à 1 pour 11 tests → long
- Incohérence DB/validation non détectée automatiquement
- Linter auto-format → retry Edit

---

### 3. Sur le Process Kaizen

**Amélioration continue fonctionne :**
- Session 1 : découverte du projet
- Session 2 : refactoring majeur (commits 1-16)
- Session 3 (actuelle) : cleanup + bugs + nouvelle feature

**Progression visible :**
- Plus d'autonomie sur implémentation technique
- Meilleure structuration (TodoWrite systématique)
- Documentation plus complète (checkpoint + log final)

**Prochaine itération :**
- Intégrer checkpoints proposés (DB/validation, Edit robuste, Triage tests)
- Tester sur nouvelle feature similaire
- Mesurer gain autonomie

---

## 🎯 Recommandations Actionnables

### Pour Prochaine Session (Feature Similaire)

**Phase Préparation :**
1. ✅ Créer TodoWrite avec toutes les étapes prévues
2. ✅ Lister fichiers impactés estimés (< 10 fichiers = OK)
3. ✅ Identifier tests existants similaires à lire

**Phase Implémentation :**
1. ✅ Utiliser pattern Read-Then-Edit systématiquement
2. ✅ Checkpoint DB/validation quand uniqueness modifiée
3. ✅ TodoWrite update à chaque étape complétée

**Phase Tests :**
1. ✅ Grouper tests pending par similarité
2. ✅ Proposer décisions par batch (3 groupes max)
3. ✅ Si > 10 tests pending → checkpoint fichier markdown

**Phase Finalisation :**
1. ✅ Vérifier cohérence DB/validation une dernière fois
2. ✅ Commit message structuré (contexte + technique + tests)
3. ✅ Log complet avec métriques et learnings

---

### Pour essentials.md

**Ajouts proposés :**

1. **Section "Checkpoints" :**
   - Checkpoint DB/validation uniqueness
   - Checkpoint session longue (> 2h)

2. **Section "Patterns" :**
   - Pattern triage tests pending
   - Pattern Edit robuste (retry sur linter)

3. **Section "Métriques Qualité" :**
   - Ratio autonomie agent/user cible : 70/30
   - Tests comme documentation (> 80% behavior covered)

---

## 📝 Décision Finale

**Status :** ✅ **SESSION RÉUSSIE**

**Critères validés :**
- ✅ Feature implémentée complètement (schema change detection)
- ✅ 73 tests passent (0 régression)
- ✅ 3 bugs critiques corrigés
- ✅ Migration DB cohérente
- ✅ Documentation complète
- ✅ Commit mergeable

**Critères partiels :**
- ⚠️ Temps > prévu (3h30 vs. ~2h estimé)
- ⚠️ User intervention nécessaire (bugs, validation DB)

**ROI :**
- Temps agent : 3h30
- Temps user : 30 min (feedback + validation)
- **Total : 4h** pour feature complexe + 73 tests + 3 bugs
- **Estimation si 100% manuel :** 8-10h
- **Gain : 50-60%** de temps

**Amélirations à tester :**
- [ ] Checkpoint DB/validation automatique
- [ ] Pattern triage tests pending (batch de 3)
- [ ] Checkpoint mi-session (> 2h)

---

## 🔄 Prochaines Étapes

**Intégrer à essentials.md :**
1. Ajouter "Checkpoint Validation Uniqueness" (section Checkpoints)
2. Ajouter "Pattern Triage Tests Pending" (section Patterns)
3. Ajouter "Checkpoint Session Longue" (section Process)

**Tester sur prochaine feature :**
- Feature similaire (refactoring + tests)
- Mesurer si temps réduit (objectif : < 3h)
- Mesurer si autonomie augmente (objectif : 80/20)

**Documenter :**
- Session 4 kaizen (après test des améliorations)
- Comparer métriques session 3 vs. session 4

---

**Note :** Ce kaizen suit le cycle PDCA du Lean :
- **Plan** : Identifier améliorations (checkpoints DB, triage tests)
- **Do** : Tester sur prochaine session
- **Check** : Mesurer impact (temps, autonomie)
- **Act** : Intégrer ou ajuster

**L'amélioration continue n'est jamais finie. On itère.**

---

*Kaizen créé le : 2026-03-10*
*Contexte : POC 4-features (Implementation Feature Complexe)*
*Résultat : ✅ SUCCÈS avec améliorations identifiées*
