# Patterns Agent-Friendly

**Version :** 3.0 — 11 patterns validés

---

## Index

| # | Pattern | Trigger | Do | Don't | N validé |
|---|---------|---------|-----|-------|----------|
| 1 | Migration DB Safe | Add colonne NOT NULL sur table existante | 3 commits : nullable → backfill → constraint | NOT NULL direct, index unique sans backfill | 2 |
| 2 | Query Object DRY | Logique métier répétée 3+ fois | Extraire dans `app/queries/ns/name_query.rb` + spec | Service trop complexe, logique dans controller/view | 2 |
| 3 | Tests Verts / Commit | Tout commit | Interleave code + specs dans chaque commit | Code commits 4-14, tests commits 15-16 | 6 |
| 4 | State Checks Explicites | Code avec state machines | `.state&.in?(['queued', 'running'])` | Boolean combinations (`persisted? && !failed?`) | 4 |
| 5 | Breaking Change Bloc | Changement signature job/service | Bloc : change signature → fix call-sites → merge en bloc | Éparpiller call-sites sur 10 commits | 2 |
| 6 | Tests Séparés | Tests system + unit à créer | Commit N-1 : system specs, Commit N : unit specs | Mélanger features et tests dans même commit | 6 |
| 7 | Self-Documenting Variables | Nesting > 2 niveaux | Variables nommées + if/elsif/else unique | Conditions imbriquées 4 niveaux | 1 |
| 8 | Checkpoint Validation Uniqueness | `validates :x, uniqueness: { scope: }` | Vérifier index DB match scope validation | Validation sans index (SQLite OK, PG crash) | 1 |
| 9 | Tests Isolation Before Actions | Controller avec `before_action` vérifiant DB | Setup context complet dans `before` block | Test sans records → before_action redirige | 4 |
| 10 | Entry Point Intelligent | Workflow multi-étapes (wizard, tunnel) | Détecter parcours actif → reprendre ou créer | User gère manuellement les IDs | 1 |
| 11 | A11y Baseline | Changement de vue/composant/formulaire | Labels, focus management, heading hierarchy, contrastes RGAA, aria-live, clavier | A11y en "Phase 7 optionnelle" | 0 |

---

## Pattern 1 : Migration DB Safe (3 commits)

**Commit 1 : Add column (nullable)**
```ruby
class AddColumnToTable < ActiveRecord::Migration[7.0]
  def change
    add_column :table, :column, :string
    add_index :table, :column
  end
end
```

**Commit 2 : Backfill data (MaintenanceTask idempotente)**
```ruby
module Maintenance
  class BackfillColumnTask < MaintenanceTasks::Task
    def collection = Model.where(column: nil)
    def process(record) = record.update!(column: compute_value)
  end
end
```

**Commit 3 : Add constraints**
```ruby
class AddConstraintsToColumn < ActiveRecord::Migration[7.0]
  def change
    change_column_null :table, :column, false
    remove_index :table, :column
    add_index :table, [:scope_col, :column], unique: true
  end
end
```

Strong Migrations : si table > 1M rows → `disable_ddl_transaction!` + `algorithm: :concurrently`

---

## Pattern 5 : Breaking Change Bloc

**Commit N : Change signature (BREAKING)**
```
job: update JobName signature (BREAKING)

BREAKING CHANGE: Add param_name parameter

Call-sites to update:
- [ ] app/jobs/cron/related_job.rb
- [ ] app/controllers/ns/controller.rb
- [ ] spec/jobs/ns/job_spec.rb

⚠️ Tests broken until commits N+1, N+2 fix all call-sites
Merge commits N to N+2 en bloc
```

**Commit N+1..N+X : Fix call-sites** (un par commit, tests verts au dernier)

Trouver call-sites : `grep -r "JobName.perform" app/ lib/ spec/`
