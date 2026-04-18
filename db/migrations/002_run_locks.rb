Sequel.migration do
  change do
    alter_table(:runs) do
      add_column :started_at, Integer
      add_column :finished_at, Integer
      add_column :success, TrueClass
      add_column :turns_used, Integer
      add_column :files_changed, Integer
      add_column :output_path, String
    end

    # Backfill: existing rows have created_at but no started_at
    self[:runs].update(started_at: :created_at)
  end
end
