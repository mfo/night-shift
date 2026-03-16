# Epic 3 : Types de tâches

**Status :** En cours — 4 skills implémentés, en exploration

---

## Objectif

Identifier les tâches répétitives d'un projet et créer des skills pour les déléguer à un agent.

## Skills implémentés

| Skill | POC | Description | Maturité |
|---|---|---|---|
| `haml-migration` | 1-haml | Migration HAML → ERB | Testable |
| `test-optimization` | 2-test-optimization | Optimisation tests lents | En création |
| `bugfix` | 3-bugs | Investigation + correction bugs | En création |
| `feature-*` (4 skills) | 4-features | Workflow features en 4 phases | En création |

**Transversaux :** `kaizen` (write + synth), `review-3-amigos` (PM + UX + Dev)

## Critères pour identifier une tâche délégable

- Répétitive (revient souvent, même structure)
- Vérifiable (tests, linters, diff visuel)
- Réversible (git revert si ça ne marche pas)
- Bornée (périmètre clair, pas de décision d'architecture)

## Échelle de maturité

1. **En création** — skill en cours d'écriture, pas encore testé en conditions réelles
2. **Testable** — le créateur peut l'utiliser, résultats corrects
3. **Adopté** — un autre dev peut l'utiliser sans assistance
4. **Production-ready** — utilisable en série, métriques de qualité

`haml-migration` est au stade 2, les autres au stade 1.
