# ROADMAP — État réel et prochaines étapes

**Dernière mise à jour :** 2026-03-20

---

## Ce qui existe

### Skills en place

| Skill | POC | État |
|---|---|---|
| `haml-migration` | 1 | 4 itérations, validation visuelle MCP Playwright, prêt pour autonomie |
| `test-optimization` | 2 | Skill + spec v4 + inventaire 52 fichiers |
| `bugfix` | 3 | 3 bugs traités (Mistral 429, snowball renewal, watermark jpeg) |
| `feature-spec` | 4 | Testé sur 1 feature (simpliscore tunnel_id) |
| `feature-plan` | 4 | Testé sur 1 feature (simpliscore tunnel_id) |
| `feature-implementation` | 4 | Testé sur 1 feature (simpliscore tunnel_id) |
| `feature-review` | 4 | Testé sur 1 feature (simpliscore tunnel_id) |
| `kaizen` | — | 2 modes : write (post-it) + synth (amélioration skills) |
| `review-3-amigos` | — | Review PM + UX + Dev sur n'importe quel input |

### PRs ouvertes sur demarches-simplifiees.fr

Chaque POC a produit au moins une PR sur le projet cible :

| POC | PR | Titre | État |
|---|---|---|---|
| 1 — HAML | [#12796](https://github.com/demarche-numerique/demarche.numerique.gouv.fr/pull/12796) | Migration haml → erb (1ère PR de production) | Open |
| 2 — Tests | [#12788](https://github.com/demarche-numerique/demarche.numerique.gouv.fr/pull/12788) | perf(tests): let_it_be — dossier_spec.rb (WIP, collecte techniques équipe) | Open |
| 3 — Bugs | [#12785](https://github.com/demarche-numerique/demarche.numerique.gouv.fr/pull/12785) | Correctif renouvellement de session (mail en double) | Open |
| 4 — Features | [#12764](https://github.com/demarche-numerique/demarche.numerique.gouv.fr/pull/12764) | Amélioration UX écrans simpliscore | Open |

### Kaizen accumulés

| Catégorie | Itérations | Fichiers kaizen |
|---|---|---|
| HAML | 4 | ~15 fichiers |
| Bugs | 3 | 5 fichiers |
| Features | 1 | 9 fichiers |
| Test-optimization | 0 | — |
| Transverse | — | 1 weekly, 1 friction skill |

---

## En cours

### POC 1 — HAML (passage en autonomie)

Skill mature (4 itérations). Équipe OK pour recevoir des PRs en continu. Stock : 758 fichiers (206 components + 552 views).

**PR en cours :** [#12796](https://github.com/demarche-numerique/demarche.numerique.gouv.fr/pull/12796) — 1ère PR de production.

**Prochaine action :** trouver un mécanisme pour enchaîner les PRs automatiquement quand la précédente est mergée.

### POC 2 — Test optimization

Spec v4 prête, skill prêt, inventaire 52 fichiers. PR #12788 ouverte en WIP pour récolter les techniques d'optimisation auprès de l'équipe avant de lancer en autonomie.

**Prochaine action :** intégrer le feedback équipe dans `patterns.md`, puis lancer le skill sur un premier fichier en supervisé.

**Référence :** `pocs/test-optimization/spec.md`

---

## Prochaines étapes par POC

### POC 1 — HAML
- #12796 en review (1ère PR de production)
- Trouver un mécanisme d'enchaînement automatique des PRs
- Milestone : point de contrôle à 50 fichiers migrés

### POC 2 — Tests
- Voir si #12788 est acceptée par l'équipe (validation de l'approche)
- Si oui : intégrer le feedback dans `patterns.md`, lancer en supervisé

### POC 3 — Bugs
- #12785 en review, une 2e PR en attente
- Continuer le rythme

### POC 4 — Features
- #12764 en review — envisager un meilleur découpage des PRs (trop gros d'un bloc)

### Transverse
- Séparation batch / per-item : extraire l'orchestration batch dans un skill générique
- Suivi de PRs et relance : pour les tâches répétitives (HAML, tests), mécanisme pour suivre les PRs ouvertes et relancer du batch dès qu'une PR est mergée
- MCP Sentry : connecter Sentry pour consommer le stock de bugs directement depuis l'agent
- Review → 3 Amigos : tirer automatiquement les commentaires de review d'une PR et les piper dans `/review-3-amigos` pour boucler plus vite
- Yes We Hack : récupérer les rapports de vulnérabilité, générer un test qui prouve la faille. Quasi-synchrone — besoin d'un workflow ultra-rapide (réactivité = crédibilité auprès des chercheurs)

---

## Backlog

- Skill split-PR (découper une grosse PR en petites PRs reviewables)
- Guide "Appliquer Night Shift à votre projet"

---

## Références

| Fichier | Contenu |
|---|---|
| `README.md` | Vision, workflow, structure |
| `pocs/` | Setup, specs, inventaires par POC |
| `kaizen/` | Learnings par itération |
| `.claude/skills/` | Les skills (le livrable principal) |
