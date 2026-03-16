# Epic 2 : Du POC à la série

**Status :** À venir — en attente d'un skill mature

---

## Objectif

Documenter l'approche pour passer d'un skill validé en POC (N=1) à une exécution en série (N=10, N=100).

## Questions ouvertes

- Comment lancer un skill sur un batch de fichiers/tâches ?
- Comment paralléliser (worktrees multiples) ?
- Comment agréger les résultats et décider quoi merger ?
- Comment détecter la dégradation de qualité à l'échelle ?

## Prérequis

Un skill ayant atteint le niveau **production-ready** (adoption équipe, pas seulement applicable par le créateur). Aucun skill n'est encore à ce stade.

## Pistes

- `haml-migration` est le candidat le plus avancé : skill le plus itéré (v6), 4 itérations kaizen, workflow validé sur plusieurs fichiers
- `test-optimization` a un inventaire de 52 fichiers et un workflow worktree isolé, mais n'a été testé que sur 1 fichier
- L'architecture batch a été spécifiée (`specs/2026-03-14-batch-skill-architecture.md`) mais pas implémentée
