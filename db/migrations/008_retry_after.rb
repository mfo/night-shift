Sequel.migration do
  change do
    alter_table(:backlog_items) do
      add_column :retry_after, Integer  # epoch timestamp, nil = immediately available
    end
  end
end
