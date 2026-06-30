# Autolearn — Boucle auto-améliorante

## Concept

Autolearn enrichit le flux existant `cmd_skill_run` (déjà piloté par le reconciler) avec un **juge LLM** post-échec. Il n'y a pas de runner séparé — le reconciler orchestre tout :

1. Le reconciler lance un skill via `skill-run` dans un worktree + tmux
2. Si le skill échoue, `cmd_skill_run` invoque le **juge** pour classifier l'échec
3. Si retryable → **patche patterns.md** (append-only) + reset l'item à `pending`
4. Le reconciler relance naturellement au cycle suivant (120s)
5. Répète jusqu'à succès ou max retries (3)

Chaque cycle est tracé dans SQLite (`autolearn_cycles`). Chaque patch de skill est git-commité dans le repo night-shift.

## Architecture

```
Reconciler (watch 120s)
  └─ pick_next_items → launch_skill
       └─ tmux window + worktree + serveur
            └─ nightshift skill-run <skill> <item>
                 └─ SkillRunner.run (claude -p)
                      ├─ succès → git push + gh pr create → pr_open
                      └─ échec → Judge.evaluate
                           ├─ retryable? → patch patterns.md + reset pending
                           │   └─ reconciler relance au prochain cycle
                           └─ non retryable → skip
```

Le reconciler gère l'infra (worktree, serveur, tmux, ports). `cmd_skill_run` gère la logique métier (succès/échec, juge, patches).

## Composants

### Judge (`lib/nightshift/ci/judge.rb`)

Analyse un run échoué et produit un verdict structuré (`CI::Verdict`). Inline le log digest dans le prompt (pas de lecture de fichier par le juge).

**Interface :**

```ruby
Nightshift::CI::Judge.evaluate(
  skill_name,           # "test-optimization"
  item:,                # "spec/models/dossier_spec.rb"
  log_path:,            # "/path/to/tmp/claude-test-optimization.log"
  failure_reason:       # "claude_error" | "no_diff"
)
# → CI::Verdict (T::Struct avec .verdict, .root_cause, .suggested_patch, .confidence)

Nightshift::CI::Judge.retryable?(verdict, retry_count)
# → true si retry_count < MAX_RETRIES et verdict in [skill_defect, infra_error]
```

**Verdicts possibles :**

| Verdict | Signification | Action |
|---|---|---|
| `skill_defect` | Le prompt/skill est mal configuré | Patch patterns.md + retry |
| `item_hard` | L'item est intrinsèquement trop complexe | Skip |
| `infra_error` | Erreur d'environnement (permissions, DB, setup) | Retry sans patch |
| `context_limit` | Max turns/tokens atteint sans convergence | Skip |

**Implémentation :** extrait un digest du log (erreurs + 15 derniers events, max 50KB), appel `claude -p --max-turns 5` → réponse JSON parsée (balanced brace parser). Fallback sur `infra_error` si le parse échoue.

### Pipeline (`lib/nightshift/skills/pipeline.rb`)

Point d'entrée du skill, appelé par le reconciler via `CLI.skill_run`. Gère le cycle complet :

| Méthode | Rôle |
|---|---|
| `execute` | Orchestre : run → success (push+PR) / failure (judge) |
| `handle_failure` | Invoque le juge, décide retry ou skip |
| `apply_patch` | Append dans patterns.md + git commit |
| `record_cycle` | Insert dans `autolearn_cycles` |

### Reconciler (`lib/nightshift/reconciler.rb`)

Pilote le scheduling via `pick_next_items` → `launch_skill`. Gère :
- Création du worktree + branche
- Démarrage du serveur (overmind) si `needs_server: true`
- Allocation de port et batch mode (`batch_size > 1`)
- Fenêtre tmux
- Zombie recovery (worktree/process disparu → retry pending, ou skipped si exhausted)
- Concurrence par backend (`active_by_backend[harness] < concurrency`)
- Cleanup orphan worktrees (branches `auto/` sans item running/pr_open)

### Dashboards CLI

```
nightshift autolearn status [skill]    # dashboard cycles par skill
nightshift autolearn report            # rapport 24h avec verdicts, patches, suggestions
nightshift autolearn inspect <id>      # deep-dive sur un item
```

### Migration SQLite (`006_autolearn.rb`)

**Table `autolearn_cycles` :**

| Colonne | Type | Description |
|---|---|---|
| `id` | PK | |
| `backlog_item_id` | FK | Lien vers `backlog_items` |
| `attempt` | Integer | Numéro de tentative (1..N) |
| `verdict` | String | Verdict du juge |
| `root_cause` | String | Cause racine identifiée |
| `suggested_patch` | String | Texte à ajouter dans patterns.md |
| `confidence` | Float | Confiance du juge (0.0-1.0) |
| `skill_patch_sha` | String | SHA du commit de modification du skill |
| `outcome` | String | improved / degraded / no_change / skipped |
| `log_path` | String | Chemin du log stream-json |
| `turns_used` | Integer | Nombre de turns Claude |
| `created_at` | Integer | Timestamp unix |

**Colonnes ajoutées à `backlog_items` :**
- `retry_count` (Integer, default 0)
- `last_verdict` (String)

### Meta-learning : suggestions infra (`007_infra_suggestions.rb`)

Quand le juge détecte un `infra_error`, la cause racine est stockée comme suggestion d'amélioration de nightshift-cli.

## Garde-fous

| Garde-fou | Valeur | Raison |
|---|---|---|
| Max retries par item | 3 | Au-delà, c'est du bruit |
| Zone de patch | `patterns.md` uniquement | SKILL.md = constitution, read-only |
| Cap pitfalls auto | 5 | Force review humaine via `kaizen synth` |
| Confidence threshold | ≥ 0.5 | Pas de patch si le juge doute |
| Git commit par patch | Systématique | Rollback possible |
| 1 item/skill max | Enforced par reconciler | L'équipe doit merger avant le suivant |

## Diagrammes

- Flux principal : [`docs/autolearn.mmd`](autolearn.mmd)
- Schéma SQLite complet : [`docs/schema.mmd`](schema.mmd)
