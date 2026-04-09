# Template Spécification Technique d'Architecture

---

## Checkpoints Critiques (vérifier AVANT rédaction)

- [ ] Bug architectural détecté ? → STOP patch, faire spec globale
- [ ] > 5 fichiers impactés ? → Spec obligatoire
- [ ] Décisions d'architecture nécessaires ? → Lister questions pour user
- [ ] Logique répétée 3+ fois ? → Proposer Query Object proactif

---

## Structure Obligatoire (15 sections)

```markdown
# Spec Technique : [Titre]

**Date :** YYYY-MM-DD
**Auteur :** [Agent/User]
**Status :** Draft v1
**Complexité :** [Simple / Moyenne / Complexe]

---

## 1. Contexte & Problème

[Description du problème]

### Root Cause (si bug)
[Analyse avec preuve]

### Objectifs
- [ ] Objectif 1
- [ ] Objectif 2

---

## 2. Décisions d'Architecture

### Décision N : [Titre]

**Choix :** [Solution choisie]
**Alternative :** [Solution non retenue]
**Rationale :** [Raisons — contexte métier, simplicité, coût/bénéfice]
**Impact :** [Conséquences mesurables]

### Patterns Pré-Approuvés à Détecter

- **Logique répétée 3+ fois** → Query Object (`app/queries/[namespace]/[name]_query.rb`)
- **Conditions imbriquées > 2 niveaux** → Self-documenting variables
- **State machine** → State checks explicites (`.state&.in?([...])`)
- **Controller modifie état DB mid-action** → Éviter memoization (`@var ||=`)

---

## 3. Architecture Proposée

### Vue d'ensemble
[Diagramme ASCII ou description]

### Composants impactés
1. **Modèle** : [Changements]
2. **Controller** : [Changements]
3. **Jobs** : [Changements]
4. **Services** : [Changements]
5. **Views** : [Changements]

---

## 4. Modèle (Database & ActiveRecord)

### Migrations

**Pattern Migration DB Safe (3 commits) :**
1. Add column (nullable, pas de constraint)
2. Backfill data (MaintenanceTask — voir section 9)
3. Add constraints (NOT NULL, UNIQUE — après backfill)

**Strong Migrations :** Si table volumineuse → `disable_ddl_transaction!` + `algorithm: :concurrently`

### Validations

[Validations Rails avec scope match Index DB]

**Checkpoint :** Validation Rails scope = Index DB unique ? Si incohérence → migration pour corriger.

### Index

- [ ] Index unique : [colonnes composites]
- [ ] Index performance : [colonnes fréquemment requêtées]

---

## 5. Controller

### Routes
[Config routes]

### Actions
[Code actions]

---

## 6. Jobs

### Job Signature
[Code job — si signature modifiée = BREAKING CHANGE]

### Call-sites impactés
[Liste fichiers à modifier]

---

## 7. Services / Query Objects

### Détection : Logique Répétée 3+
Si pattern métier apparaît 3+ fois → extraire dans Query Object.

### Structure Query Object
```ruby
class Namespace::QueryNameQuery
  def initialize(params)
    # ...
  end

  def result?
    # Logique centralisée
  end
end
```

**Tests :** `spec/queries/namespace/query_name_query_spec.rb`

---

## 8. Tests

**Principe :** Tests verts à chaque commit (exception documentée pour breaking changes).

### Tests à Créer
- Model specs (validations, scopes)
- Query Object specs (cas nominaux + edge cases)
- Controller specs (actions + before_actions)
- System specs (workflow E2E)
- Component specs (props, rendu)

### Tests à Modifier
[Liste des specs existantes impactées par les changements]

**Pattern :** Si > 5 tests obsolètes → grouper par similarité, proposer action par groupe (ADAPTER / SUPPRIMER / GARDER PENDING).

---

## 9. Migration de Données (Backfill)

- [ ] Script one-off ou migration ?
- [ ] Production data impact ?
- [ ] Rollback plan ?

---

## 10. Breaking Changes

### Call-sites impactés
[Résultat du grep — lister tous les fichiers à modifier]

### Plan Breaking Change (Pattern Bloc)
```
Commit N: scope: change signature (BREAKING)
Commit N+1: scope: fix call-site 1
Commit N+2: scope: fix call-site 2
→ Merge en bloc obligatoire
```

### Migration progressive (si API publique)
Phase 1 : Support double signature → Phase 2 : Migration call-sites → Phase 3 : Suppression old signature

Pour refactoring interne : préférer breaking change atomique en bloc.

---

## 11. Performance

### N+1 Queries
Pour chaque N+1 identifiée, documenter le trade-off :
- **Contexte :** volume data, fréquence, N borné ?
- **Option A (optimiser)** : coût complexité
- **Option B (garder N+1)** : justification (N petit, queries indexées, action rare)
- **Choix + rationale**

### Index à Ajouter
[Voir section 4 — Index]

---

## 12. Sécurité

### Validations
[Format, unicité, présence]

### Authorization
[Qui peut créer/modifier/voir]

---

## 13. UX / Product

### Comportement attendu
[Liste comportements]

### Edge cases
[Solutions pour chaque edge case]

---

## 14. Rollout Strategy

**Phase 1 :** Feature flag
**Phase 2 :** Scale up
**Phase 3 :** Cleanup

---

## 15. Métriques & Monitoring

### Métriques à tracker
[Liste métriques]

### Alertes à configurer
[Liste alertes]
```

---

## Checklist Spec Validée

- [ ] 15 sections complètes
- [ ] Breaking changes + call-sites
- [ ] Trade-offs + rationale
- [ ] Tests listés (créer + modifier)
- [ ] Migration données planifiée
- [ ] Performance (N+1, index)
- [ ] Sécurité (validations, authz)
- [ ] Rollout strategy
- [ ] Métriques

---

## Livrable Final

1. `specs/YYYY-MM-DD-[nom]-spec.md` (spec finale)
2. `specs/YYYY-MM-DD-[nom]-review-v1.md` (review PM)
3. `specs/YYYY-MM-DD-[nom]-review-v2.md` (validation finale)
4. `kaizen/YYYY-MM-DD-[nom]-spec.md` (kaizen)
