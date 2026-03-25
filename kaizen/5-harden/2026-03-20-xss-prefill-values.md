# Kaizen -- XSS prefill possible_values
Date: 2026-03-20 | Skill: harden-audit, harden-fix | Score: ?/10

## Ce qui s'est passé
- Faille XSS sur le prefill des `possible_values` (drop_down_list, repetition)
- Le HTML injecté via les valeurs de prefill n'était pas échappé
- Fix en 2 commits TDD : test prouvant la faille → fix (`ERB::Util.html_escape`)
- Flow harden-audit non utilisé → pas de fichier d'audit généré
- Pas de PR créée en fin de session

## Ce qui s'est bien passé
- Pattern TDD Red→Green bien exécuté (test d'abord, fix ensuite)
- Fix minimal et chirurgical (2 lignes, `ERB::Util.html_escape`)
- Commits atomiques avec messages conventionnels clairs

## Ce qui s'est mal passé
- Aucun fichier d'audit produit — le contrat harden-audit → harden-fix n'a pas été respecté
- Skills harden n'ont pas d'allowed-tools → permissions demandées interactivement à chaque commande
- Pas de PR explicative produite en fin de session

## Ce qu'on a appris
- Une faille sur un composant peut s'appliquer à plusieurs via l'héritage. Toujours remonter la hiérarchie de classes pour vérifier si d'autres composants sont impactés par la même vulnérabilité.

## Permissions bloquantes (demandées interactivement)

### harden-audit
| Permission | Pourquoi |
|---|---|
| `Bash(grep:*)` | Chercher des patterns vulnérables dans le codebase |
| `Bash(git log:*)` | Voir l'historique des fichiers impactés |
| `Bash(git diff:*)` | Comparer les versions |
| `Write` | Créer le fichier d'audit dans `audits/` |

### harden-fix
| Permission | Pourquoi |
|---|---|
| `Bash(bundle exec rspec:*)` | Lancer les tests (red puis green) |
| `Bash(git add:*)` | Stager les fichiers |
| `Bash(git commit:*)` | Commiter (avec -c commit.gpgsign=false) |
| `Bash(git diff:*)` | Voir les diffs |
| `Bash(git log:*)` | Voir l'historique |
| `Bash(git status)` | Voir le statut |
| `Bash(git checkout -b:*)` | Créer la branche de fix |
| `Bash(gh pr create:*)` | Créer la PR |
| `Bash(bundle exec rubocop:*)` | Linting ruby avant commit |

## Actions
- [ ] Renforcer le skill harden-fix : si pas de fichier d'audit, en créer un minimal avant de fixer
- [ ] Documenter dans harden-fix que la PR est obligatoire comme livrable final
- [ ] Ajouter dans harden-audit (étape 2 — reproduction) : dès l'identification du code vulnérable, remonter l'héritage et lister toutes les classes sœurs/enfants potentiellement impactées par la même faille. Le périmètre complet doit être dans le fichier d'audit avant de passer à harden-fix.
