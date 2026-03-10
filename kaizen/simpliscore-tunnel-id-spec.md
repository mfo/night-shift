# Kaizen - Refactoring Simpliscore avec tunnel_id (Phase Spec)

**Date :** 2026-03-10
**Tâche :** Spec technique d'architecture - Refactoring Simpliscore tunnel_id
**Temps :** 5h30
**Status :** ✅ SUCCÈS (spec production-ready)

---

## 🎯 Objectif vs Résultat

**Objectif initial :**
- Review PR #12764 (améliorations UX Simpliscore)

**Résultat obtenu :**
- ✅ Review PR effectuée
- ✅ Bug critique découvert (cache busting mathématiquement impossible)
- ✅ **Pivot** vers refactoring architectural complet (tunnel_id in URL)
- ✅ Spec technique 1000+ lignes avec 15 sections
- ✅ Review par agent PM (2 rounds, 15 problèmes trouvés et corrigés)
- ✅ Spec production-ready

**Gap :**
- Implémentation non faite (phase suivante)
- Temps 5h30 vs. estimation 3h initiale

---

## ✅ Ce Qui a Bien Marché

### Techniques/Patterns Efficaces

1. **Review agent PM Senior pour validation spec**
   - **Pourquoi :** A identifié 4 problèmes critiques (index unique, validation, breaking changes) que j'aurais ratés
   - **Impact :** Évité bugs en prod, spec beaucoup plus solide
   - **À réutiliser sur :** Toutes specs techniques > 500 lignes ou avec décisions d'architecture

2. **Itérations rapides avec user sur décisions d'architecture**
   - **Pourquoi :** User tranchait immédiatement sur chaque question (format tunnel_id, N+1 trade-off, auto-lancement)
   - **Impact :** Zéro blocage, avancement fluide
   - **À réutiliser sur :** Features avec trade-offs métier (perf vs. simplicité)

3. **Documentation explicite des trade-offs pragmatiques**
   - **Pourquoi :** N+1 accepté (max 10k users), auto-lancement simplifié (contrôle user) → documenté avec rationale
   - **Impact :** Pas de débat futur sur "pourquoi pas optimisé ?"
   - **À réutiliser sur :** Toute décision technique avec alternative non choisie

4. **Query Object proactif (TunnelFinishedQuery)**
   - **Pourquoi :** Duplication détectée (3 fois même logique "parcours terminé") → proposé extraction
   - **Impact :** User a approuvé immédiatement, DRY amélioré
   - **À réutiliser sur :** Dès que pattern répété 3+ fois dans une spec

5. **Preuve mathématique du bug**
   - **Pourquoi :** Au lieu de "ça marche pas", j'ai prouvé que la query créait une condition impossible (created_at >= T AND created_at < T)
   - **Impact :** Conviction immédiate du user → pivot architectural accepté
   - **À réutiliser sur :** Bugs subtils où il faut convaincre

### Autonomie

- **Charge mentale :** MOYENNE
  - Supervision user nécessaire pour décisions d'architecture
  - Mais questions pertinentes, pas de bavardage

- **Fire-and-forget :** ⚠️ Non, mais normal pour architecture
  - 8 questions légitimes (vraies décisions métier)
  - User devait trancher sur trade-offs (N+1, auto-lancement, format tunnel_id)

- **Checkpoints :** ✅ Efficaces
  - Review agent PM à mi-parcours → 15 problèmes détectés
  - Itérations rapides sans friction

---

## ⚠️ Ce Qui a Coincé

### Blocages Rencontrés

1. **Fausse alerte sur header_component.rb**
   - **Problème :** J'ai signalé un bug alors que le code était correct
   - **Cause :** Lecture trop rapide, pas assez d'attention au code existant
   - **Solution appliquée :** User m'a corrigé : "quand je regarde le fichier, le code utilise bien last_completed"
   - **Temps perdu :** 10 min
   - **Learning :** Toujours re-lire le code avant de signaler un bug

2. **Tentatives de patching au lieu de refactoring**
   - **Problème :** Après découverte bug cache busting, j'ai proposé des fixes partiels (tunnel_complete condition)
   - **Cause :** Réflexe "quick fix" au lieu de prendre du recul sur l'architecture
   - **Solution :** User a stoppé : *"attends attends, on va quand meme faire une spec avant de se lancer dans le code"*
   - **Temps perdu :** 15 min
   - **Learning :** Bug architectural → spec d'architecture, pas patch

3. **Sous-estimation du temps de spec**
   - **Problème :** Estimation mentale ~3h, réalité 5h30
   - **Cause :** Complexité sous-estimée (15 sections, 8 décisions, 2 reviews, 8 itérations)
   - **Solution :** Accepter que specs d'architecture = investissement temps
   - **Temps perdu :** N/A (bien investi)
   - **Learning :** Spec architecture = 2x temps estimé initial

### Questions Posées

- **Nombre total :** 8 questions
- **Légitimes (décisions d'architecture) :** 8
- **Évitables (prompt/context à améliorer) :** 0

**Détail des questions :**
1. Format tunnel_id ? → Choix technique (6 chars hex)
2. Auto-lancement ? → Trade-off UX/coûts
3. Backfill strategy ? → Décision data migration
4. Validation model ? → Choix robustesse
5. Parcours multiples ? → Décision UX
6. Index unique ? → Bug critique détecté en review
7. accept_simplification avec ID ? → Sécurité
8. Optimiser N+1 ? → Trade-off perf/simplicité

**Toutes légitimes** - user devait trancher sur des vraies décisions métier/architecture.

---

## 🔄 Améliorations à Apporter

### Pour essentials.md

- [ ] **Pattern pré-approuvé :** "Si bug complexe découvert → proposer spec d'architecture globale, pas patch incrémental"
- [ ] **Pattern pré-approuvé :** "Specs > 500 lignes → lancer review agent PM systématiquement"
- [ ] **Pattern DRY :** "Si logique répétée 3+ fois dans spec → proposer Query Object ou extraction"
- [ ] **Documentation trade-offs :** "Toujours documenter décisions pragmatiques avec rationale (ex: N+1 accepté car < 10k users)"

### Pour le prompt de ce type de tâche

- [ ] **Clarifier étape :** "Review PR → si bug architectural détecté → STOP et proposer spec d'architecture complète"
- [ ] **Ajouter checkpoint :** "Après spec v1 → lancer review agent PM avant de montrer au user"
- [ ] **Ajouter exemple :** Pattern Query Object pour DRY (TunnelFinishedQuery comme modèle)

### Pour le workflow général

- [ ] **Séparer phases :** "Phase Spec" distincte de "Phase Implémentation" avec validation entre les deux
- [ ] **Review agent PM :** Systématique pour specs > 500 lignes ou avec décisions d'architecture
- [ ] **Documentation trade-offs :** Template section "Décisions Pragmatiques" dans toute spec

---

## 📊 Métriques

### Temps

- **Temps prévu :** ~3h (estimation initiale)
- **Temps réel :** 5h30
- **Écart :** +2h30 (mais justifié)
- **Répartition :**
  - Review PR initiale : 30 min
  - Découverte bug + preuve : 45 min
  - Création spec v1 : 2h
  - Review agent PM : 45 min
  - Itérations corrections (8 rounds) : 1h30

### Qualité

- **Spec complète :** ✅ 15 sections, 1000+ lignes
- **Review findings :** 15 problèmes trouvés (4 critiques, 11 importants) → tous corrigés
- **Mergeable :** ✅ Production-ready selon review v2

### Autonomie

- **Agent-friendly score :** 7/10
  - Supervision user nécessaire pour décisions d'architecture (attendu)
  - Questions pertinentes (8/8 légitimes)
  - Review agent PM utilisé efficacement
  - Itérations rapides sans friction
  - **Pas 9-10 car :** Pas fire-and-forget (normal pour architecture)
  - **Pas 4-6 car :** Questions pertinentes, pas de bavardage, autonome sur rédaction

---

## 💡 Learnings Clés

### Ce que j'ai appris sur CE projet

1. **Simpliscore a une architecture date-based fragile**
   - TunnelFinder basé sur created_at ranges → complexe et buggy
   - Refactoring tunnel_id = simplification majeure (-100 lignes, +50 lignes nettes)

2. **User privilégie simplicité > optimisation prématurée**
   - N+1 accepté car max 10k users
   - Philosophie : "code simple maintenable > code optimisé complexe"

3. **Breaking changes = point critique à documenter**
   - Review agent PM a insisté sur section Breaking Changes
   - User a validé : signature job change = 3 call-sites à modifier (critique)

### Ce que j'ai appris sur l'IA & ce type de tâche

1. **Specs d'architecture = agent-friendly avec review agent**
   - Score 7/10 seul
   - Score 9/10 avec review agent PM
   - Pattern : Agent rédige → Agent PM review → User tranche

2. **Questions sur trade-offs ≠ bavardage inutile**
   - Les 8 questions étaient toutes légitimes
   - User devait décider (métier/architecture)
   - = Bon usage de l'autonomie (demander quand nécessaire)

3. **Documentation trade-offs = valeur ajoutée**
   - Review v2 : "pourquoi pas optimisé ?" → réponse déjà dans spec
   - Évite débats futurs
   - Clarté pour équipe future

### Hypothèses Validées

- ✅ **Review agent PM** est efficace pour specs techniques complexes (15 problèmes détectés)
- ✅ **Itérations rapides** user + agent fonctionnent bien (8 rounds sans friction)
- ✅ **Query Object proactif** est apprécié (user a approuvé immédiatement)
- ⏳ **Fire-and-forget pour specs architecture** = irréaliste (décisions métier nécessaires)

---

## 🚀 Prochaines Actions

### Pour la prochaine tâche similaire (spec architecture)

1. **STOP si bug architectural détecté** → proposer spec globale, pas patch
2. **Lancer review agent PM** systématiquement pour specs > 500 lignes
3. **Documenter trade-offs** dans section dédiée avec rationale claire
4. **Proposer Query Object** dès que pattern répété 3+ fois
5. **Estimer temps = 2x** estimation initiale pour specs d'architecture

### Pour améliorer le process

1. **Créer template spec architecture** avec sections standard (Routes, Controller, Jobs, Breaking Changes, Trade-offs)
2. **Workflow en 3 phases :**
   - Phase 1 : Spec v1 (agent autonome)
   - Phase 2 : Review agent PM (validation automatique)
   - Phase 3 : User review + décisions (itérations rapides)
3. **Checklist breaking changes :** grep systématique des call-sites impactés

---

## 🎓 Patterns Agent-Friendly Découverts

### Pattern 1 : Review itérative avec agent PM

**Contexte :** Spec technique > 500 lignes avec décisions d'architecture

**Workflow :**
1. Agent rédige spec v1 (autonome)
2. Agent lance review agent PM (autonome)
3. Agent corrige problèmes détectés (itérations)
4. User valide et tranche sur décisions métier

**Avantages :**
- Qualité spec supérieure (review double)
- User se concentre sur décisions métier, pas détails techniques
- Itérations rapides

**Agent-friendly score :** 9/10 (supervision légère)

---

### Pattern 2 : Documentation trade-offs pragmatiques

**Contexte :** Décision technique avec alternative (N+1 accepté, optimisation non faite)

**Template :**
```markdown
## Décision : [Titre]

**Choix :** [Solution choisie]

**Alternative :** [Solution non retenue]

**Rationale :**
- [Raison 1 - contexte métier]
- [Raison 2 - simplicité vs. complexité]
- [Raison 3 - coût/bénéfice]

**Impact :** [Conséquences mesurables]
```

**Avantages :**
- Évite débats futurs "pourquoi pas optimisé ?"
- Clarté pour équipe future
- Décision traçable

**Agent-friendly score :** 10/10 (pattern réutilisable systématiquement)

---

### Pattern 3 : Query Object pour DRY

**Contexte :** Logique répétée 3+ fois dans codebase

**Détection :**
- Grep pattern récurrent
- Compter occurrences
- Si ≥ 3 → proposer extraction

**Solution :**
```ruby
# app/queries/llm/tunnel_finished_query.rb
class LLM::TunnelFinishedQuery
  def finished?
    # Logique centralisée
  end
end
```

**Avantages :**
- DRY appliqué
- Testable isolément
- Extensible (méthodes bonus)

**Agent-friendly score :** 9/10 (nécessite détection pattern, mais autonome après)

---

## 📈 Impact Projet Night Shift

### Contribution à essentials.md

**Patterns à ajouter :**
1. Workflow specs architecture en 3 phases
2. Review agent PM systématique (> 500 lignes)
3. Template documentation trade-offs
4. Pattern Query Object pour DRY

**Interdictions à clarifier :**
- ❌ Patch incrémental si bug architectural → spec globale required

**Commandes utiles à ajouter :**
- `grep -r "JobName.perform" app/ lib/ spec/` → trouver call-sites breaking changes

---

## 🔗 Références

**Fichiers produits :**
- `tunnel_spec.md` (1000+ lignes, 15 sections)
- `review-tunnel_spec.md` (review v1, 15 problèmes)
- `review-tunnel_spec-v2.md` (validation finale)

**Décisions clés :**
- tunnel_id = 6 chars hex (`SecureRandom.hex(3)`)
- Index unique `[:procedure_revision_id, :tunnel_id, :rule]`
- Query Object `TunnelFinishedQuery` pour DRY
- N+1 accepté (trade-off documenté)
- Auto-lancement simplifié (contrôle user)

---

**Note :** Ce kaizen documente la phase **Spécification**. Phase **Implémentation** à venir (8-12h estimées).

**Learning principal :** Specs d'architecture = agent-friendly à **7/10 seul**, **9/10 avec review agent PM**. Investissement temps (5h30) largement justifié par qualité finale production-ready.
