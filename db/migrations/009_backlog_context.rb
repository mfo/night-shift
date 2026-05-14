Sequel.migration do
  change do
    add_column :backlog_items, :context, String, text: true
  end
end
