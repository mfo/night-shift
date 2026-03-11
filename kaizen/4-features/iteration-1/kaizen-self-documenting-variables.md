# Proposition d'Amélioration - essentials.md

**Date :** 2026-03-11
**Proposé par :** Agent Claude
**Contexte :** Session 6 - Implémentation feature Simpliscore (refactoring SimpliscoreConcern avec workflow tunnel_id)

---

## 🎯 Problème Identifié

**Situation observée :**
Lors du refactoring de `SimpliscoreConcern`, l'action `simplify` contenait initialement 33 lignes avec 4 niveaux de nesting (conditionnels imbriqués). Cette complexité rendait le code difficile à lire et à maintenir. L'utilisateur a demandé plusieurs itérations de simplification successive, guidant vers une approche par **self-documenting variables** plutôt que commentaires ou extraction de méthodes privées.

**Pattern appliqué avec succès :**
```ruby
# AVANT (33 lignes, 4 niveaux de nesting)
def simplify
  @tunnel_id = params[:tunnel_id]
  current_rule = params[:rule]
  query = LLM::TunnelQuery.new(procedure_revision: draft, tunnel_id: @tunnel_id)
  current_suggestion = query.find_for_rule(rule: current_rule)

  if current_suggestion&.state&.in?(['accepted', 'skipped'])
    last_completed_step = query.last_completed_step

    if last_completed_step
      next_rule = LLM::Rule.next_rule(last_completed_step.rule)

      if next_rule
        redirect_to simplify_admin_procedure_types_de_champ_path(...)
        return
      else
        if current_rule != last_completed_step.rule
          redirect_to simplify_admin_procedure_types_de_champ_path(...)
          return
        end
      end
    end
  end

  @llm_rule_suggestion = current_suggestion || query.build_for_rule(rule: current_rule)
end

# APRÈS (18 lignes, 1 niveau de nesting)
def simplify
  @tunnel_id = params[:tunnel_id]
  current_suggestion = tunnel_query.find_for_rule(rule: params[:rule])

  # Self-documenting variables remplacent les conditionnels imbriqués
  current_step_finished = current_suggestion&.state&.in?(['accepted', 'skipped'])
  last_completed_step = tunnel_query.last_completed_step if current_step_finished
  next_rule = LLM::Rule.next_rule(last_completed_step.rule) if last_completed_step
  visiting_different_step = last_completed_step && params[:rule] != last_completed_step.rule

  if next_rule
    redirect_to simplify_admin_procedure_types_de_champ_path(@procedure, tunnel_id: @tunnel_id, rule: next_rule)
  elsif visiting_different_step
    redirect_to simplify_admin_procedure_types_de_champ_path(@procedure, tunnel_id: @tunnel_id, rule: last_completed_step.rule)
  else
    @llm_rule_suggestion = current_suggestion || tunnel_query.build_for_rule(rule: params[:rule])
  end
end
```

**Résultat :**
- Réduction de 33 → 18 lignes (-45%)
- Réduction de 4 → 1 niveau de nesting (-75%)
- Lisibilité grandement améliorée
- Tests tous passants sans modification

**Fréquence :**
- 3 fois rencontré sur cette session (actions `simplify`, `accept_simplification`, `new_simplify`)
- Pattern applicable à toute action controller avec logique conditionnelle complexe
- Estimé ~20% des controllers dans demarche.numerique.gouv.fr pourraient bénéficier de ce pattern

**Impact :**
- **Temps perdu :** ~15-30 min par action complexe pour comprendre la logique imbriquée
- **Charge mentale :** ÉLEVÉE (maintenir le contexte à travers 4 niveaux de nesting)
- **Risque :** Bugs dans les conditions edge cases, difficultés de maintenance

**Preuve/Exemples :**
- Session 6, Action `simplify` : 4 niveaux de nesting → 1 niveau
- Session 6, Action `accept_simplification` : 48 lignes → 17 lignes avec extraction de `apply_suggestion`
- Session 6, Action `new_simplify` : 40 lignes → 16 lignes avec extraction logique vers TunnelQuery

---

## ✅ Solution Proposée

### Type d'Amélioration
- [x] Nouveau pattern pré-approuvé
- [ ] Nouvelle interdiction
- [ ] Nouveau checkpoint
- [ ] Clarification existante
- [ ] Nouvelle commande utile
- [ ] Autre : [préciser]

### Contenu Proposé

**Texte à ajouter/modifier dans essentials.md :**

```markdown
## Pattern: Self-Documenting Variables pour Réduire Complexité

**Quand :** Actions controller avec conditionnels imbriqués (> 2 niveaux de nesting)

**Pourquoi :** Améliorer lisibilité, réduire charge cognitive, faciliter maintenance

**Comment :**

1. **Extraire les conditions en variables nommées explicitement**
   ```ruby
   # ❌ AVANT: Conditions imbriquées
   if current_suggestion&.state&.in?(['accepted', 'skipped'])
     last_step = query.last_completed_step
     if last_step
       next_rule = LLM::Rule.next_rule(last_step.rule)
       if next_rule
         redirect_to path(rule: next_rule)
       else
         if params[:rule] != last_step.rule
           redirect_to path(rule: last_step.rule)
         end
       end
     end
   end

   # ✅ APRÈS: Self-documenting variables
   current_step_finished = current_suggestion&.state&.in?(['accepted', 'skipped'])
   last_completed_step = query.last_completed_step if current_step_finished
   next_rule = LLM::Rule.next_rule(last_completed_step.rule) if last_completed_step
   visiting_different_step = last_completed_step && params[:rule] != last_completed_step.rule

   if next_rule
     redirect_to path(rule: next_rule)
   elsif visiting_different_step
     redirect_to path(rule: last_completed_step.rule)
   else
     # default case
   end
   ```

2. **Préférer variables explicites aux commentaires**
   ```ruby
   # ❌ Commentaires qui expliquent
   # Check if user has completed onboarding and has active subscription
   if user.onboarding_completed_at.present? && user.subscription&.active?

   # ✅ Variable qui documente
   user_ready_for_feature = user.onboarding_completed_at.present? && user.subscription&.active?
   if user_ready_for_feature
   ```

3. **Remplacer early returns multiples par if/elsif/else unique**
   ```ruby
   # ⚠️ ACCEPTABLE mais moins lisible
   if next_rule
     redirect_to path(rule: next_rule)
     return
   end

   if visiting_different_step
     redirect_to path(rule: last_step.rule)
     return
   end

   @suggestion = current || build_new

   # ✅ PRÉFÉRÉ: Structure unique
   if next_rule
     redirect_to path(rule: next_rule)
   elsif visiting_different_step
     redirect_to path(rule: last_step.rule)
   else
     @suggestion = current || build_new
   end
   ```

**Bénéfices :**
- Réduction nesting (4 niveaux → 1 niveau typique)
- Code auto-documenté (pas de commentaires nécessaires)
- Tests plus faciles (variables testables individuellement si besoin)
- Refactoring incrémental possible (une variable à la fois)

**Limites :**
- Ne pas créer variables pour conditions triviales (`if user.admin?` → OK tel quel)
- Ne pas sur-découper (max 4-5 variables self-documenting par action)
- Si > 5 variables → considérer extraction Service Object ou Query Object

**Voir aussi :** Pattern Query Object pour extraction logique métier complexe
```

**Section cible :** Patterns & Best Practices (créer si n'existe pas)

**Placement :** Après patterns existants (Service Objects, Query Objects, etc.)

---

## 🧪 Validation

### Hypothèse
Si on pré-approuve le pattern "self-documenting variables" pour réduire nesting dans actions controller, alors:
1. Claude appliquera ce pattern automatiquement lors de refactoring
2. Les actions complexes seront réduites de ~40-50% en lignes
3. Le nesting sera réduit de 3-4 niveaux à 1 niveau
4. Gain de temps ~15-20 min par action refactorisée (pas besoin de multiples itérations)

**Exemple hypothèse testée :**
> "Si on documente ce pattern dans essentials.md, alors lors d'une prochaine feature avec controller complexe, Claude proposera spontanément ce refactoring sans avoir besoin de 3-4 rounds d'itération avec l'utilisateur."

### Critères de Succès

**Cette amélioration sera considérée comme réussie si :**
1. Sur 3 prochaines tâches avec actions controller complexes (> 2 niveaux nesting), Claude applique le pattern dans ≥ 2 cas
2. Réduction moyenne de nesting de 3+ niveaux à 1-2 niveaux
3. Nombre d'itérations de refactoring réduit de ~3-4 à ~1-2 par action
4. L'utilisateur ne doit pas guider vers ce pattern (Claude le propose spontanément)

**À mesurer sur :** 5 prochaines tâches impliquant refactoring de controllers (POC 4-features)

### Risques

**Risques potentiels de cette amélioration :**
- **Sur-application** (MOYEN) - Claude pourrait créer trop de variables pour conditions triviales
  - **Mitigation :** Documenter clairement les limites (pas pour conditions simples, max 4-5 variables)
- **Confusion avec extraction méthode** (FAIBLE) - Hésitation entre variables vs méthodes privées
  - **Mitigation :** Clarifier quand utiliser quoi (variables pour conditions, méthodes pour logique réutilisable)
- **Verbosité excessive** (FAIBLE) - Noms de variables trop longs
  - **Mitigation :** Montrer exemples avec noms concis mais clairs

---

## 📊 Impact Estimé

### Tâches Concernées
- **Types de tâches :**
  - Refactoring controllers complexes
  - Implémentation nouvelles features avec logique conditionnelle
  - Review/cleanup code legacy avec nesting profond
- **Fréquence estimée :** ~2-3 tâches/semaine (sur projet demarche.numerique.gouv.fr)
- **Volume total :** ~20% des 150+ controllers pourraient bénéficier de ce pattern

### Gain Espéré

**Par tâche :**
- Temps gagné : ~15-20 min (évite 2-3 rounds d'itération de refactoring)
- Questions évitées : 3-5 (clarifications sur structure conditionnelle)
- Risque d'erreur réduit : MOYEN (moins de nesting = moins de bugs conditionnels)

**Par semaine (si fréquence = 2-3/semaine) :**
- Temps total gagné : ~30-60 min
- Charge mentale : IMPACT ÉLEVÉ (code plus lisible = maintenance plus facile)

### Coût

**Coût d'implémentation :**
- Temps rédaction : ~15 min (ce document kaizen)
- Temps validation : ~30 min (ajouter à essentials.md + tester sur 1 exemple)
- Risque confusion : FAIBLE (pattern simple et démontré)

**ROI estimé :** POSITIF
- Coût unique: ~45 min
- Gain récurrent: ~30-60 min/semaine
- Break-even: < 1 semaine

---

## 🔄 Itération

### Version Proposée

**v1 (cette proposition) :**
Voir section "Contenu Proposé" ci-dessus.

**Pourquoi cette formulation :**
- **Exemples concrets AVANT/APRÈS** : Montre le pattern en action (plus efficace qu'explication abstraite)
- **3 règles simples** : Facile à retenir et appliquer (variables explicites, pas commentaires, if/elsif/else unique)
- **Bénéfices + Limites** : Évite sur-application (clarifie quand NE PAS utiliser)
- **Lien avec Query Object** : Montre progression naturelle (variables → Query Object pour logique plus complexe)

### Évolutions Futures Possibles

**Si v1 validée, on pourrait ensuite :**
- Ajouter pattern "Guard Clauses" pour early returns justifiés (validations, authorizations)
- Documenter quand extraire vers Service Object vs Query Object vs Self-documenting variables
- Créer checklist "Complexity Red Flags" (> 3 niveaux nesting → refactor obligatoire)

**Si v1 invalide, alternatives :**
- Version minimaliste : Juste dire "Réduire nesting avec variables explicites" sans exemples détaillés
- Version spécifique : Seulement pour SimpliscoreConcern (pas générique)

---

## 📝 Historique (après test)

### Test 1
**Date :** [À FAIRE - prochaine feature POC 4]
**Tâche :** [Référence]
**Résultat :** [✅ Validé / ⚠️ Mitigé / ❌ Invalidé]
**Observations :** [Détails]

### Test 2
**Date :** [À FAIRE]
**Tâche :** [Référence]
**Résultat :** [✅ Validé / ⚠️ Mitigé / ❌ Invalidé]
**Observations :** [Détails]

### Décision Finale
- [ ] ✅ **ACCEPTÉ** - Intégré dans essentials.md le [DATE]
- [ ] ⚠️ **ACCEPTÉ avec modifications** - Version modifiée : [lien]
- [ ] 🔄 **À RETESTER** - Après ajustements : [lesquels]
- [ ] ❌ **REJETÉ** - Raison : [pourquoi]

---

## 💡 Learnings de Cette Proposition

**Ce que cette amélioration révèle sur :**

### Le Projet
- **Complexité accumulée** : Les controllers legacy accumulent du nesting au fil des features ajoutées
- **Dette technique graduelle** : Chaque ajout de condition imbriquée rend le code 10% plus difficile à lire
- **Patterns Rails classiques** : Les actions controller avec redirections multiples sont courantes (wizard flows, state machines)
- **Migration HAML→ERB en cours** : Refactoring controllers est opportun pendant migration frontend

### L'Agent-Friendliness
- **Itérations multiples coûteuses** : Sans ce pattern documenté, l'utilisateur a dû guider 3-4 rounds de simplification
- **Exemples > Théorie** : Montrer AVANT/APRÈS est plus efficace que dire "réduire la complexité"
- **Variables auto-documentées = moins de questions** : Code lisible réduit besoin de clarifications
- **Patterns pré-approuvés accélèrent** : Si Claude sait que ce pattern est OK, pas besoin de demander permission

### Le Process Kaizen
- **Small wins compound** : Pattern simple (variables explicites) → impact massif (-45% lignes, -75% nesting)
- **Refactoring guidé révèle patterns** : Les 3-4 itérations avec utilisateur ont permis d'identifier le bon pattern
- **Documentation = scalability** : Ce qui a pris 3-4 rounds ici pourra être fait en 1 round la prochaine fois
- **Mesurable ≠ théorique** : Pattern validé par réduction mesurable (33→18 lignes, 4→1 nesting)

**Learning clé :**
> "Les patterns de refactoring efficaces émergent de sessions réelles, pas de théorie. Documenter ce qui a marché permet de scaler la qualité sans scaler le temps de supervision."

---

## ⚠️ Template d'Usage

**Quand utiliser ce template :**
- ✅ Pattern récurrent (≥ 2 occurrences) → ✅ (3 actions refactorisées avec ce pattern)
- ✅ Impact mesurable (temps/qualité/autonomie) → ✅ (~15-20 min gagné/tâche)
- ✅ Solution claire et testable → ✅ (AVANT/APRÈS démontré)

**Quand NE PAS utiliser :**
- ❌ Cas unique/exceptionnel → N/A (pattern applicable largement)
- ❌ Solution floue ou complexe → N/A (pattern simple: variables + if/elsif/else)
- ❌ Micro-optimisation < 2min d'impact → N/A (gain ~15-20 min/tâche)

**Principe :** Amélioration continue ≠ complexification continue.
**On ajoute à essentials.md si et seulement si ça réduit la complexité globale.**

✅ **Cette proposition respecte le principe** : Réduit complexité (nesting, lignes) et améliore autonomie Claude.

---

## 🎯 Annexe: Contexte Session 6

### Résumé Session
- **Feature :** Implémentation workflow Simpliscore avec tunnel_id
- **Durée :** ~3-4h
- **Fichiers modifiés :** 15+ (migrations, models, controllers, views, specs)
- **Tests :** 119 examples, 0 failures ✅
- **Refactoring majeur :** SimpliscoreConcern (70 lignes supprimées, 4→1 nesting)

### Workflow Utilisateur Observé
1. User: "peux-tu relancer les tests j'ai fais les changement..."
2. Tests passent, user demande refactoring
3. User: "parlons de ce #4" (redirection logic)
4. Je propose options, user demande "option 3" (early returns)
5. Je refactore → user: "je me demande si on ne pourrait pas avoir un gros if/else ?"
6. Je refactore avec if/elsif/else → user: "parfait, appliquons ces changements"
7. Tests passent → user demande autres simplifications
8. ... 3-4 rounds similaires ...

**Learning :** User avait vision claire du pattern final, mais a guidé itérativement. Si pattern documenté, 1 round suffirait.

### Code Review Final
User a reçu 6 points de review:
- Points 1, 2, 3: "osf" (on s'en fout)
- Point 5 (determinisme): "OK tu peux y aller direct"
- Point 6 (error handling): "on va rien faire la dessus, les erreurs vont remonter dans sentry"

**Learning :** User pragmatique, préfère solutions simples et déléguées. Pattern self-documenting variables = match parfait pour cette approche.

---

**Note :** Ce template suit le cycle PDCA (Plan-Do-Check-Act) du Kaizen.
