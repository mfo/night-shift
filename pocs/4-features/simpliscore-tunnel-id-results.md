# Feature : Refactoring Simpliscore avec tunnel_id - Résultats Phase Spec

**Date :** 2026-03-10
**Feature :** Refactoring Simpliscore - Architecture tunnel_id dans URL
**Phase :** Spécification technique
**Worktree :** `/Users/mfo/dev/demarches-simplifiees.fr-ux-review-simpliscore`

---

## ⏱️ Timeline

**Début :** ~10:00
**Fin :** ~15:30
**Durée totale :** ~5h30

**Détail :**
- Review PR initiale (#12764) : 30 min
- Découverte bug cache busting : 45 min
- Création tunnel_spec.md v1 : 2h
- Review tunnel_spec.md (agent) : 45 min
- Itérations corrections (8 points) : 1h30

---

## 🎯 Objectif vs Résultat

**Objectif initial :**
Review PR #12764 (amélioration UX Simpliscore) en français

**Résultat obtenu :**
1. ✅ Review PR effectuée
2. ✅ Bug critique découvert (cache busting impossible)
3. ✅ Pivot vers refactoring architectural (tunnel_id in URL)
4. ✅ Spec technique complète (tunnel_spec.md - 1000+ lignes)
5. ✅ Review par agent PM Senior (2 rounds)
6. ✅ Spec production-ready après corrections

**Gap :**
- Implémentation pas encore faite (phase suivante)
- Choix pragmatiques documentés (N+1 accepté, auto-lancement simplifié)

---

## 🤖 Comportement de Claude

### Phase 1 : Review PR

**Questions Posées : 0**
- Autonome sur l'analyse de la PR
- A identifié un faux-positif de bug (corrigé par user)

**Erreur initiale :**
- Fausse alerte sur `header_component.rb` (timestamp logic)
- User a corrigé : le code était en fait correct

### Phase 2 : Découverte Bug Critique

**Analyse autonome :**
- ✅ Preuve mathématique que cache busting créait query impossible
- ✅ Proposition de fix initial (tunnel_complete condition)
- ❌ User a identifié que le fix introduisait un autre bug

**Learning :**
User a stoppé les tentatives de patching : *"attends attends, on va quand meme faire une spec avant de se lancer dans le code"*

### Phase 3 : Architecture Pivot

**User guidance :**
User a proposé l'idée clé : *"attends plutot qu'avoir un tunnel id en session, je prefererais l'avoir dans l'url"*

**Questions posées : 8**
Toutes légitimes pour les décisions d'architecture :
1. Format du tunnel_id ? → `SecureRandom.hex(3)` (6 chars)
2. Auto-lancement des étapes ? → Oui, pour UX fluide
3. Que faire si schema change ? → Backfill avec MaintenanceTask
4. Validation au niveau model ? → Oui, toutes les validations
5. Gestion parcours multiples ? → Un seul actif à la fois
6. Index unique ? → `[:procedure_revision_id, :tunnel_id, :rule]`
7. Stratégie accept_simplification ? → Passer ID dans URL
8. N+1 queries ? → Accepté comme trade-off pragmatique

**Autonomie :** ⚠️ Supervision nécessaire mais pertinente
- Questions = vraies décisions d'architecture
- Pas de bavardage inutile
- User devait trancher sur trade-offs métier

### Phase 4 : Review Itérative

**Agent PM Senior lancé :** ✅
Review v1 a trouvé **4 problèmes critiques + 11 importants**

**Itération corrections :**
- 8 rounds de corrections
- User a tranché sur chaque point
- Spec finale production-ready

---

## ✅ Résultats Techniques

### Spec Technique Créée

**Fichier :** `/Users/mfo/dev/demarches-simplifiees.fr-ux-review-simpliscore/tunnel_spec.md`
**Taille :** 1000+ lignes
**Sections :** 15

**Contenu :**
1. Routes (nouvelles + anciennes)
2. Controller (nouvelles actions + modifs)
3. Jobs (signature changée)
4. Migration DB (tunnel_id + indexes)
5. Components (liens mis à jour)
6. Services (TunnelFinder supprimé)
7. Backfill strategy (MaintenanceTask)
8. Tests (mise à jour)
9. Factories (tunnel_id ajouté)
10. Model validations
11. **Query Object** (TunnelFinishedQuery - DRY)
12. Bénéfices du refactoring
13. **Breaking Changes** (3 call-sites documentés)
14. Ordre d'implémentation
15. Questions résolues (8 décisions architecturales)

### Review Findings

**Review v1 (critique) :**
- 🔴 4 problèmes critiques (index, validation, accept_simplification, breaking changes)
- 🟡 11 problèmes importants

**Review v2 (après corrections) :**
- ✅ Tous les critiques résolus
- 🟡 3 points restants (N+1, auto-lancement, doc incohérente)
- ✅ Spec **APPROUVÉE avec réserves mineures**

**Status final :** ✅ Production-ready

---

## 📝 Décisions d'Architecture

### 1. tunnel_id dans URL (pas en session)
**Choix :** `/simplify/:tunnel_id/:rule`
**Rationale :** RESTful, bookmarkable, testable, stateless

### 2. Format tunnel_id = 6 chars hex
**Choix :** `SecureRandom.hex(3)` → `a1b2c3`
**Rationale :** 16.7M possibilités, lisible, URL-safe

### 3. Index unique avec :rule
**Choix :** `[:procedure_revision_id, :tunnel_id, :rule]`
**Rationale :** 4 suggestions par tunnel (1 par étape)

### 4. Query Object pour DRY
**Choix :** `LLM::TunnelFinishedQuery`
**Rationale :** Centralise logique "parcours terminé" (3 duplications éliminées)

### 5. Accept avec ID explicite
**Choix :** Route `post 'simplify/:tunnel_id/:rule/accept/:id'`
**Rationale :** Sécurité + évite ambiguïté

### 6. Trade-off N+1 queries accepté
**Choix :** Ne pas optimiser `new_simplify`
**Rationale :** Max 10k users, simplicité > optimisation prématurée

### 7. Auto-lancement simplifié
**Choix :** Seulement pour nouvelles suggestions, pas pour `failed`
**Rationale :** Contrôle utilisateur + évite retry loops coûteuses

### 8. Backfill avec MaintenanceTask
**Choix :** Détecter séquences `improve_label` → reconstruire tunnels
**Rationale :** Simple, précis, gère edge cases

---

## 🎯 Évaluation

### Critères de Succès (Phase Spec)

**Compréhension de la tâche :**
- [ ] ✅ Review PR autonome
- [ ] ✅ Bug critique identifié
- [ ] ⚠️ Besoin guidance user pour pivot architectural (normal)

**Qualité de la spec :**
- [ ] ✅ Complète (1000+ lignes, 15 sections)
- [ ] ✅ Décisions architecturales documentées (8 questions résolues)
- [ ] ✅ Breaking changes identifiés (3 call-sites)
- [ ] ✅ DRY appliqué (Query Object)
- [ ] ✅ Trade-offs pragmatiques documentés

**Processus itératif :**
- [ ] ✅ Review agent PM utilisé efficacement
- [ ] ✅ 8 rounds de corrections sans friction
- [ ] ✅ User a tranché sur décisions métier
- [ ] ✅ Spec finale production-ready

**Temps :**
- [ ] ⚠️ 5h30 (au-dessus estimation initiale de 3h)
- [ ] ✅ Mais spec très complète + 2 reviews

### Note Globale

**Score : 4.5/5**

- ✅ Spec production-ready
- ✅ Review itérative efficace
- ✅ Décisions architecturales solides
- ✅ Query Object (amélioration proactive)
- ⚠️ Temps supérieur à estimation (mais justifié par complexité)

---

## 💡 Learnings

### Ce qui a bien marché

1. **Review agent PM Senior**
   - **Pourquoi :** A trouvé 4 critiques + 11 importants que j'aurais ratés
   - **À réutiliser sur :** Toutes specs techniques complexes

2. **Itérations rapides**
   - **Pourquoi :** User tranchait sur chaque point → pas de blocage
   - **À réutiliser sur :** Architecture avec trade-offs métier

3. **Documentation des trade-offs**
   - **Pourquoi :** N+1 et auto-lancement clarifiés dans spec
   - **À réutiliser sur :** Toute décision pragmatique vs. théorique

4. **Query Object proactif**
   - **Pourquoi :** User n'avait pas demandé, mais a approuvé immédiatement
   - **À réutiliser sur :** Patterns de code où duplication détectée

### Ce qui a coincé

1. **Fausse alerte sur header_component.rb**
   - **Problème :** J'ai cru voir un bug alors que le code était correct
   - **Cause :** Lecture trop rapide du code existant
   - **Solution :** User m'a corrigé immédiatement
   - **Temps perdu :** 10 min

2. **Tentatives de patching au lieu de refactoring**
   - **Problème :** Après découverte bug, j'ai proposé des fixes partiels
   - **Cause :** Pas assez de recul pour voir l'architecture globale
   - **Solution :** User a stoppé : "on va faire une spec avant"
   - **Temps perdu :** 15 min

3. **Sous-estimation temps de spec**
   - **Problème :** Estimation 3h, réalité 5h30
   - **Cause :** Complexité sous-estimée (15 sections, 8 décisions, 2 reviews)
   - **Solution :** Accepter que les specs d'architecture prennent du temps
   - **Temps perdu :** N/A (temps bien investi)

### Améliorations à apporter

**Au prompt :**
- [ ] Ajouter : "Si bug complexe découvert → proposer spec d'architecture, pas patch"
- [ ] Ajouter : "Toujours lancer review agent pour specs > 500 lignes"

**Au contexte (essentials.md potentiel) :**
- [ ] Pattern : "Review itérative avec agent PM pour specs architecturales"
- [ ] Pattern : "Query Object pour DRY quand logique répétée 3+ fois"
- [ ] Trade-off : "N+1 acceptable si < 10k users et code plus simple"

**Au workflow :**
- [ ] Phase "Spec" séparée de phase "Implémentation"
- [ ] Review agent PM systématique pour specs complexes
- [ ] Documentation trade-offs obligatoire

---

## 🚀 Prochaines Actions

### Phase Implémentation (non faite)

**Étapes prévues :**
1. [ ] Migration DB (ajouter tunnel_id)
2. [ ] Model validations
3. [ ] Routes (nouvelles routes avec tunnel_id)
4. [ ] Controller concern (nouvelles actions + modifs)
5. [ ] Query Object (TunnelFinishedQuery)
6. [ ] Jobs (signature changée)
7. [ ] Components (liens mis à jour)
8. [ ] Factories (tunnel_id)
9. [ ] Tests (mise à jour)
10. [ ] Cleanup (supprimer TunnelFinder)
11. [ ] Backfill (MaintenanceTask)

**Estimation implémentation :** 8-12h (basé sur spec)

**Prêt pour :** ✅ Implémentation immédiate

---

## 📊 Comparaison avec Objectif

**Objectif initial :**
- Review PR simple en français

**Résultat :**
- Review PR ✅
- Bug critique découvert ✅
- **Pivot** vers refactoring architectural
- Spec technique complète production-ready ✅

**Gain vs. faire soi-même :**
- **Review agent PM** : aurait pris 2-3h de review humaine
- **Spec structurée** : aurait pris 6-8h seul
- **Temps réel** : 5h30 (user + agent)
- **Gain estimé** : 50% de temps, qualité supérieure (review double)

**Conclusion :**
✅ **SUCCÈS** - Spec production-ready avec review itérative efficace. Pivot architectural bien géré. Prêt pour implémentation.

---

## 🔗 Liens

**Worktree :** `/Users/mfo/dev/demarches-simplifiees.fr-ux-review-simpliscore`
**Branche :** `ux-review-simpliscore`
**PR Review :** #12764
**Spec :** `tunnel_spec.md`
**Review v1 :** `review-tunnel_spec.md`
**Review v2 :** `review-tunnel_spec-v2.md`

---

*Résultats documentés le : 2026-03-10*
*Phase : Spécification technique*
*Phase implémentation : À venir*
