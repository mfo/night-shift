Sequel.migration do
  change do
    create_table(:prs) do
      Integer :number, primary_key: true
      String :branch, null: false
      String :state, null: false, default: "draft"
      String :github_state
      String :ci
      String :review_decision
      Integer :review_count, default: 0
      TrueClass :auto_merge, default: false
      TrueClass :deployed, default: false
      String :reviewer
      String :updated_at
      Integer :synced_at
    end

    create_table(:transitions) do
      primary_key :id
      foreign_key :pr_number, :prs, on_delete: :cascade
      String :from_state, null: false
      String :to_state, null: false
      Integer :created_at, null: false
      index [:pr_number, :created_at]
    end

    create_table(:runs) do
      primary_key :id
      foreign_key :pr_number, :prs, on_delete: :cascade
      String :kind, null: false
      Integer :created_at, null: false
      index [:pr_number, :created_at]
    end

    create_table(:settings) do
      String :key, primary_key: true
      String :value
    end
  end
end
