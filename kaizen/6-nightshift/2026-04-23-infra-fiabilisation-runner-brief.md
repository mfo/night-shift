---
status: traité
date_synth: 2026-04-23
skill: nightshift
---

# Kaizen -- Fiabilisation infra runner + brief
Date: 2026-04-23 | Skill: nightshift (infra) | Score: 8/10

## Ce qui s'est passe

Session de debug/fix sur l'infra nightshift apres plusieurs runs auto echoues. Diagnostic de 5 problemes lies entre eux, tous corriges dans la meme session.

## Ce qui s'est bien passe

- Diagnostic methodique en partant des logs claude (`tmp/claude-test-optimization.log`)
- Identification de la root cause commune (--allowedTools jamais passe)
- Pattern coverage.sh inspire du precedent screenshot-gist (reuse d'architecture)
- Simplification du quickstart en enlevant ce que le hook post-checkout fait deja

## Ce qui s'est mal passe

1. **`--allowedTools` jamais passe** : `skill_runner.rb` n'extrayait pas les allowed-tools du frontmatter SKILL.md — toutes les permissions custom etaient ignorees en mode auto. Root cause de TOUS les echecs de permissions (coverage, rm, bun lint:herb, etc.)
2. **Issue comments absents du brief** : `fetch_review_comments` utilisait `pulls/{n}/comments` (review comments inline) mais pas `issues/{n}/comments` (commentaires de conversation)
3. **Fenetres tmux doublonnees** : `attach.rb` creait une fenetre pour chaque worktree auto/, puis `reconciler.rb` en creait une deuxieme pour le meme skill
4. **Ping-pong transitions bruyantes** : le brief affichait chaque transition individuelle au lieu de les collapser par PR
5. **Setup redondant dans quickstart** : l'agent perdait du temps a refaire bundle/DB deja fait par le hook post-checkout

## Ce qu'on a appris

- **`--allowedTools` est critique** : sans ce flag, `--permission-mode acceptEdits` ne suffit pas pour les Bash commands — elles sont toutes auto-deny en mode non-interactif (`-p`). C'est le flag qui dit a Claude CLI "ces outils sont pre-approuves"
- **Pattern script wrapper** : quand une operation necessite plusieurs permissions (rm + COVERAGE=true + ruby extraction), la wrapper dans un script .sh et autoriser `Bash(script.sh:*)` est plus robuste que d'autoriser chaque commande individuellement
- **GitHub API distinction** : `pulls/{n}/comments` = review comments (inline sur le diff), `issues/{n}/comments` = conversation comments. Les deux sont necessaires pour un brief complet
- **tmux window_id (@N) vs window_index** : utiliser `@branch` comme metadata custom pour identifier les fenetres par branche, pas par index

## Permissions bloquantes (demandees interactivement)

Aucune — cette session etait sur le repo night-shift (pas un run auto).

## Actions

- [x] `skill_runner.rb` : extraire allowed-tools du frontmatter YAML et passer `--allowedTools` au CLI
- [x] `coverage.sh` : script wrapper pour coverage (rm + run + extraction)
- [x] `SKILL.md` test-optimization : simplifier permissions, ajouter `Bash(.claude/skills/test-optimization/coverage.sh:*)`
- [x] `quickstart.md` : supprimer toute notion de worktree, commencer par `spring start`
- [x] `brief.rb` : ajouter `fetch_issue_comments` + collapser transitions ping-pong
- [x] `reconciler.rb` : `find_window_by_branch` + reuse fenetre existante
- [x] `attach.rb` : nommage robot pour worktrees auto
- [ ] Committer les changements
