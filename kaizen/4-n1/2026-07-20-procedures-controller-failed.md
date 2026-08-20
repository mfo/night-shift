---
status: traité
date_synth: 2026-08-20
status: traité
date_synth: 2026-08-20
---

# Kaizen — n1-query-fix failed on procedures_controller

## Ce qui s'est passé

Session auto n1-query-fix sur `app/controllers/instructeurs/procedures_controller.rb` (worktree `auto-n1-query-fix-c-i-procedures_controller`). 59 turns, ~47 min wall-clock, $5.76.

## Ce qui a bien marché

- **Setup Prosopite** : bundle install OK, spec_helper et test.rb patched
- **Skill context** : 6 N+1 patterns détectés (active_storage_attachments ×4, dossier_corrections ×1), 2 endpoints ciblés
- **Analyse et subagents** : le skill a correctement identifié 2 patterns et lancé 2 subagents en parallèle :
  - Subagent 1 : `Export.find_or_create_fresh_export` → ajout `.with_attached_file` dans la query scope, tests OK (105 examples, 0 failures)
  - Subagent 2 : `Commentaire#flagged_pending_correction?` → remplacement par `association(:dossier_correction).loaded?` guard clause, edit appliqué

## Ce qui a mal marché

1. **Permission denied (1)** : `rm -f tmp/prosopite-scan.log && bundle exec rspec ... | tee tmp/prosopite-scan.log` — le scan Prosopite final a été refusé. Pas de vérification N+1 post-fix.

2. **Background task timeout (600s)** : les 2 subagents lancés en parallèle ont dépassé le plafond de 600s et ont été tués. Le subagent Export était en train de lancer les specs (bundle exec rspec, ~21s de tests), le subagent Commentaire avait fini son edit mais n'a pas pu committer.

3. **Context window overflow (cause racine)** : au turn 59, le prompt atteint **101043 tokens** vs limite **100000 tokens** du modèle deepseek-v4-flash. L'API renvoie `400 Prompt has 101043 tokens, but the configured context size is 100000 tokens`. Le skill est en `claude_error`.

4. **Aucun commit ni PR** : les 2 fixes sont appliqués dans le worktree mais n'ont pas été commités/pushés/PR-és. Le travail est perdu.

## Permissions bloquantes

- `Bash: rm -f tmp/prosopite-scan.log && bundle exec rspec spec/controllers/instructeurs/procedures_controller_spec.rb 2>&1 | tee tmp/prosopite-scan.log` — le scan Prosopite avec tee a été refusé. C'est le même pattern que le kaizen du 2026-06-26 (archives-controller-ok.md) : `tee` dans une commande rspec déclenche un refus.

## Actions

1. **Autoriser le scan Prosopite** : ajouter la permission pour `bundle exec rspec ... | tee tmp/prosopite-scan.log` dans `.claude/settings.json` du repo cible. Sans ça, la boucle de vérification N+1 est toujours bloquée.

2. **Augmenter le timeout background tasks** : 600s est trop court pour des subagents qui lancent `bundle exec rspec` (~21s de tests + bundle load + fixtures). Soit passer `CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS=0`, soit monter le timeout à 120s.

3. **Context window mitigation** : le overflow à 100k tokens arrive après 59 turns + 2 subagents. Solutions possibles :
   - Utiliser Opus 4.8 (200k context) au lieu de deepseek-v4-flash (100k)
   - Réduire le nombre de reads/turns dans le skill principal en passant plus tôt aux subagents
   - Ajouter un check de context usage avant le lancement des subagents et `compact` si nécessaire

4. **Recover les fixes perdus** : les edits sont dans le worktree mais pas commités. Si le worktree existe encore, récupérer les diffs. Sinon, les fixes sont à refaire (simple : `.with_attached_file` dans `Export.find_or_create_fresh_export` et guard clause sur `Commentaire#flagged_pending_correction?`).

## Liens

- [[2026-06-26-archives-controller-ok.md]] — même permission denied sur `tee` dans scan Prosopite
- [[2026-07-08-procedure-clone-concern-failed.md]] — même context overflow (100129>100000) sur deepseek-v4-flash
