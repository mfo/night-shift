Sequel.migration do
  change do
    add_column :backlog_items, :priority, Integer, default: 0
  end
end
