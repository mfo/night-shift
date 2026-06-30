Sequel.migration do
  change do
    alter_table(:backlog_items) do
      add_foreign_key [:pr_number], :prs, key: :number, on_delete: :set_null
    end
  end
end
