# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:backlog_items) do
      primary_key :id
      String :skill, null: false
      String :item, null: false
      String :status, null: false, default: 'pending'
      String :branch
      Integer :pr_number
      String :failure_reason
      Integer :created_at, null: false
      Integer :updated_at, null: false

      index %i[skill status]
      unique %i[skill item]
    end
  end
end
