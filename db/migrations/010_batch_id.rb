# frozen_string_literal: true

Sequel.migration do
  change do
    add_column :backlog_items, :batch_id, String
  end
end
