Sequel.migration do
  change do
    create_table(:autolearn_cycles) do
      primary_key :id
      Integer :backlog_item_id, null: false
      Integer :attempt, null: false
      String :verdict          # skill_defect, item_hard, infra_error, context_limit
      String :root_cause
      String :suggested_patch
      Float :confidence
      String :skill_patch_sha  # git commit SHA of the skill modification (nil if no patch)
      String :outcome          # improved, degraded, no_change, skipped
      String :log_path
      Integer :turns_used
      Integer :created_at, null: false

      index [:backlog_item_id, :attempt]
    end

    alter_table(:backlog_items) do
      add_column :retry_count, Integer, default: 0
      add_column :last_verdict, String
    end
  end
end
