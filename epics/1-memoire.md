# Epic 1 : Cycle Kaizen

**Status :** ✅ Implémenté

---

## Objectif

Créer une boucle d'amélioration continue des skills à partir des retours terrain.

## Le cycle

```
Session de travail (skill en action)
    ↓
/kaizen write — l'agent documente ce qui s'est passé
    ↓
kaizen/<catégorie>/<date>-<titre>.md (livrable passif)
    ↓
/kaizen synth — l'humain consomme les kaizen
    ↓
Propositions de modifications au skill (patterns, pièges, règles)
    ↓
Validation humaine → skill amélioré → commit
```

## Principes

- **Write** est passif : on dépose, on n'applique pas
- **Synth** est interactif : rien n'est écrit sans validation
- Les kaizen documentent aussi les **échecs** — c'est le matériau le plus précieux
- Les patterns validés migrent vers le skill (`patterns.md`), pas vers un fichier centralisé

## Implémentation

- Skill : `.claude/skills/kaizen/SKILL.md`
- Kaizen par POC : `kaizen/{1-haml,2-test-optimization,3-bugs,4-features}/`
- Templates : `kaizen/templates/`
