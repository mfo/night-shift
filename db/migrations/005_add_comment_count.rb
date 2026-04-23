Sequel.migration do
  change do
    add_column :prs, :comment_count, Integer, default: 0
  end
end
