Sequel.migration do
  change do
    # Harness effectivement reserve au moment du claim : la plage horaire peut
    # basculer pendant qu'un item tourne, le comptage de concurrence doit
    # rester attache au binaire reellement occupe.
    add_column :backlog_items, :harness, String
  end
end
