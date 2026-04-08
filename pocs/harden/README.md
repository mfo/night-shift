# POC 5 — Harden (Sécurité applicative)

**Objectif :** Renforcer la sécurité d'une app — explorer, qualifier, corriger.

**3 skills, 1 pipeline :**

```
Surface d'attaque (endpoint, controller, feature)
    ↓
/harden-pentest                         ← Explorer, découvrir
    ↓ produit des rapports bruts
/harden-audit                           ← Qualifier, scorer, expliquer
    ↓ produit
audits/YYYY-MM-DD-[slug]-audit.md  (status: qualified)
    ↓ consommé par
/harden-fix audits/YYYY-MM-DD-[slug]-audit.md   ← Corriger (TDD)
    ↓ met à jour
audits/YYYY-MM-DD-[slug]-audit.md  (status: fixed, fix_pr: URL)
```

On peut entrer dans le pipeline à n'importe quelle étape :
- Faille déjà connue (YesWeHack, CVE) → `/harden-audit` directement
- Faille déjà qualifiée → `/harden-fix` directement
- Exploration proactive → `/harden-pentest`

## Skills

| Skill | Rôle |
|---|---|
| `harden-pentest` | Explorer une surface d'attaque (white-box), découvrir des failles |
| `harden-audit` | Qualifier la faille : reproduire, scorer DREAD /15, expliquer à l'équipe |
| `harden-fix` | Corriger : test rouge (prouve la faille) → test vert (corrige) → PR pédagogique |

## Workflow

1. **Exploration** (`/harden-pentest`) — cartographier, chercher les vecteurs, produire des rapports bruts
2. **Audit** (`/harden-audit`) — qualification DREAD, classification OWASP, parcours explicatif équipe
3. **Décision** — fix immédiat / sprint courant / backlog / accepter le risque
4. **Fix** (`/harden-fix`) — TDD sécurité (red → green), PR explicative

## Fichiers d'audit

Les fichiers d'audit vivent dans `audits/` à la racine du projet. Ils servent de contrat entre audit et fix, et de trace pour l'équipe.

## Kaizen

Learnings dans `kaizen/5-harden/`.
