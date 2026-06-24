# Template Spécification Technique d'Architecture

---

## Checkpoints Critiques (vérifier AVANT rédaction)

- [ ] Bug architectural détecté ? → STOP patch, faire spec globale
- [ ] > 5 fichiers impactés ? → Spec obligatoire
- [ ] Décisions d'architecture nécessaires ? → Lister questions pour user
- [ ] Logique répétée 3+ fois ? → Proposer Query Object proactif

---

## Structure Obligatoire (16 sections)

```markdown
# Spec Technique : [Titre]

**Date :** YYYY-MM-DD
**Auteur :** [Agent/User]
**Status :** Draft v1 | Validated
**Complexité :** [Simple / Moyenne / Complexe]
**Issue Source :** [URL issue GitHub ou N/A]

---

## 1. Contexte & Problème (co-écrit avec le user en Étape -1)

**Intent :** [pourquoi on fait ça — problème à résoudre]
**Outcome :** [état final voulu]
**Scope :** [ce qui est couvert]
**Non-goals :** [ce qui est explicitement hors scope]
**Constraints :** [limites techniques/métier/deadline]
**Success criteria :** [comment on sait que c'est fini]

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

### Request Flow
[route → controller → service → model → DB → view]

### Side Effect Chain
[event → callback/job → effet externe (email, webhook, log audit)]

### Authorization Surface
- Qui déclenche l'action ?
- Quelle policy / before_action ?
- Élargit-on ou restreint-on l'accès ?

### Failure Modes
- Écriture DB échoue → [conséquence / fallback]
- Job échoue → [retry ? dead letter ?]
- Service externe down → [timeout ? fallback ?]

### Composants impactés
1. **Modèle** : [Changements]
2. **Controller** : [Changements]
3. **Jobs** : [Changements]
4. **Services** : [Changements]
5. **Views** : [Changements]
6. **Concerns** : [Changements]
7. **Mailers / Notifications** : [Changements]
8. **Policies (Pundit)** : [Changements]

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

### Comportements Implicites

Grep sur les modèles touchés — documenter les effets invisibles :
- Callbacks (`after_/before_/around_`) → quels effets déclenchés ?
- Concerns inclus → quels callbacks ajoutent-ils ?
- `dependent: :destroy` → volume de l'association ?
- Scopes / `default_scope` → impactés par le changement ?
- Serializers / `as_json` → le modèle est-il exposé en API ?
- Mailers / Notifications → déclenchés par les callbacks ?

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

### Authorization / IDOR

| Endpoint | Rôles autorisés | Mécanisme |
|----------|----------------|-----------|
| [action] | [admin/instructeur/usager] | [policy Pundit / before_action / scope] |

Questions à résoudre :
- L'accès est-il scopé au bon niveau ? (procédure, groupe instructeur, dossier)
- Un usager peut-il accéder aux ressources d'un autre ? (IDOR)
- Élargit-on ou restreint-on les accès existants ?

### RGPD / Données Personnelles

- Données personnelles touchées : [lesquelles]
- Traçabilité : [audit log existant ? à créer ?]
- Purge / anonymisation : [impact sur les mécanismes existants]
- Consentement : [changement de finalité ?]

---

## 13. UX / Product

### Comportement attendu
[Liste comportements]

### Edge cases
[Solutions pour chaque edge case]

### Accessibilité (RGAA)

- [ ] Navigation clavier complète ?
- [ ] Labels formulaires explicites ?
- [ ] Contrastes suffisants (4.5:1 texte, 3:1 éléments UI) ?
- [ ] aria-live pour contenu dynamique ?
- [ ] Heading hierarchy respectée ?
- [ ] Responsive (mobile/tablette) ?

---

## 14. Validation Visuelle

_Remplir si le changement a un impact sur l'interface (vue, composant, libellé, layout). Supprimer cette section sinon._

Tout changement visuel doit être documenté dans la PR pour permettre la review.

### Quand capturer
- Changement de vue/partial/composant
- Modification de libellé, placeholder, message d'erreur
- Ajout/suppression d'un élément d'interface
- Changement de logique d'affichage conditionnel (droits, états)

### Scénario de capture
- **URL :** [chemin de la page à capturer]
- **Auth :** administrateur | instructeur | usager (via dev-auto-login)
- **Setup console :** [commandes Rails pour se donner les droits / trouver une démarche adaptée]
- **Actions :** [naviguer, cliquer, remplir — ou "aucune" si page statique]
- **Capturer :** [quel élément/page screenshoter]

Pour trouver une démarche de test adaptée, interroger la DB de dev :
```bash
.claude/skills/feature-spec/find-procedure.sh "Procedure.joins(:types_de_champ_public).where(types_de_champ: { type_champ: 'communes' }).limit(5).pluck(:id, :libelle)"
```

### Variantes à couvrir
- [ ] État nominal
- [ ] État vide (liste vide, aucun résultat)
- [ ] Cas limite (texte long, rôles différents, états variés)

### Dans la PR
- Section "Aperçu visuel" avec captures avant/après (si modification)
- Si l'issue source a des maquettes UX : comparaison attendu vs obtenu
- Captures hébergées via screenshot-gist

---

## 15. Rollout Considerations

- [ ] Feature flag nécessaire ? (touche du user-facing multi-rôle → oui)
- [ ] Déploiement incrémental ? (migration volumineuse → oui)
- [ ] Backward compat requise ? (API consommée par d'autres → oui)
- [ ] Backfill avant code ? (colonne NOT NULL → oui)

---

## 16. Métriques & Monitoring

### Métriques à tracker
[Liste métriques]

### Alertes à configurer
[Liste alertes]
```

---

## Checklist Spec Validée

- [ ] 16 sections complètes
- [ ] Breaking changes + call-sites
- [ ] Trade-offs + rationale
- [ ] Tests listés (créer + modifier)
- [ ] Migration données planifiée
- [ ] Performance (N+1, index)
- [ ] Sécurité (validations, authz)
- [ ] Rollout considerations
- [ ] Métriques

---

## Livrable Final

1. `specs/YYYY-MM-DD-[nom]-spec.md` (spec finale)
2. `specs/YYYY-MM-DD-[nom]-review-v1.md` (review PM)
3. `specs/YYYY-MM-DD-[nom]-review-v2.md` (validation finale)
4. `kaizen/YYYY-MM-DD-[nom]-spec.md` (kaizen)
