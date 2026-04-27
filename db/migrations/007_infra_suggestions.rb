Sequel.migration do
  change do
    create_table(:infra_suggestions) do
      primary_key :id
      String :skill, null: false
      String :source, null: false       # "preflight", "judge", "manual"
      String :description, null: false   # la suggestion lisible
      String :target                     # fichier/module nightshift concerne (ex: "reconciler.rb")
      Integer :backlog_item_id           # item qui a declenche la suggestion (nullable)
      Integer :occurrences, default: 1   # combien de fois la meme suggestion est apparue
      String :status, default: "pending" # pending, accepted, rejected, implemented
      Integer :created_at, null: false
      Integer :resolved_at

      index [:skill, :status]
      index :status
    end
  end
end
