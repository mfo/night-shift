# Feedback : haml-migration — readiness pour autonomie

**Date :** 2026-03-17

---

## Contexte

Le skill `haml-migration` a 4 itérations de kaizen et une PR de démo validée par l'équipe ([#12760](https://github.com/demarche-numerique/demarche.numerique.gouv.fr/pull/12760)). L'équipe est OK pour recevoir ce type de PRs en continu et créer automatiquement la suivante quand la précédente est mergée.

**Stock à migrer :** 206 components + 552 views = 758 fichiers.

**Première PR de production :** [#12796](https://github.com/demarche-numerique/demarche.numerique.gouv.fr/pull/12796)

## Projection

| Rythme | Durée estimée |
|---|---|
| 1/jour | ~35 mois |
| 2/jour | ~17 mois |
| 3/jour | ~12 mois |
| 5/jour | ~7 mois |

Les components sont plus complexes que les views — le rythme réel sera non-linéaire.

## Revue à 5 (Dev IA, Senior Tech, Entrepreneur, DevOps, PO/PM)

### Ce qui marche

- Skill mature : 430 lignes, checklist 17 points, patterns validés par 4 itérations
- Validation visuelle (Playwright + gist screenshots) = preuve formelle de non-régression
- PRs standardisées, reviewables en 5 min
- Extraction i18n intégrée dans le workflow

### Ce qui manque

1. **Mémoire opérationnelle** — le skill ne sait pas où il en est entre deux runs. Pas de tracking PR courante, fichiers migrés, prochain fichier. Bloqueur pour l'autonomie.
2. **Métriques** — pas de suivi durée/tokens/taux de succès par run
3. **Priorisation** — pas d'ordre de migration (par usage, complexité, criticité)
4. **Accord d'équipe formalisé** — rythme, rotation review, kill switch

### Risques identifiés

- **Auto-login patch** : risque de commit accidentel → besoin d'un pre-commit hook
- **Conflits de merge** : si d'autres devs touchent les mêmes fichiers
- **Fatigue review** : l'équipe peut se lasser de reviewer des PRs identiques
- **Pas d'isolation** : le skill tourne dans le même workspace que le dev

## Prochaines étapes

- Trouver un mécanisme pour enchaîner automatiquement les PRs quand la précédente est mergée
- Milestone : point de contrôle à 50 fichiers migrés avec métriques + revue équipe
