module Nightshift
  class Store
    attr_reader :db

    def initialize(db = Nightshift.db)
      @db = db
    end

    def upsert(pr)
      db[:prs].insert_conflict(target: :number, update: {
        branch: pr.branch, state: pr.state.to_s, github_state: pr.github_state,
        ci: pr.ci, review_decision: pr.review_decision,
        review_count: pr.review_count.to_i, auto_merge: pr.auto_merge ? true : false,
        deployed: pr.deployed ? true : false, reviewer: pr.reviewer,
        updated_at: pr.updated_at, synced_at: Time.now.to_i
      }).insert(pr.to_db_hash)
    end

    def get_state(pr_number)
      row = db[:prs].where(number: pr_number).first
      row&.dig(:state)&.to_sym
    end

    def record_transition(pr_number, from, to)
      db[:transitions].insert(
        pr_number: pr_number, from_state: from.to_s,
        to_state: to.to_s, created_at: Time.now.to_i
      )
    end

    def circuit_breaker?(pr_number, kind: "autofix",
                         max: ENV.fetch("NIGHTSHIFT_AUTOFIX_MAX").to_i,
                         window: ENV.fetch("NIGHTSHIFT_AUTOFIX_WINDOW").to_i)
      db[:runs]
        .where(pr_number: pr_number, kind: kind)
        .where { created_at > Time.now.to_i - window }
        .count >= max
    end

    def record_run(pr_number, kind:)
      db[:runs].insert(pr_number: pr_number, kind: kind, created_at: Time.now.to_i)
    end

    def get_setting(key)
      db[:settings].where(key: key).get(:value)
    end

    def set_setting(key, value)
      db[:settings].insert_conflict(target: :key, update: { value: value.to_s })
        .insert(key: key, value: value.to_s)
    end

    def all_prs(github_state: nil)
      ds = db[:prs]
      ds = ds.where(github_state: github_state) if github_state
      ds.all
    end

    def fresh?(ttl: 60)
      synced = db[:prs].max(:synced_at)
      synced && (Time.now.to_i - synced.to_i) < ttl
    end

    def reconcile_pr(pr)
      old_state = get_state(pr.number)
      new_state = pr.state

      db.transaction do
        upsert(pr)
        if old_state && old_state != new_state
          record_transition(pr.number, old_state, new_state)
        end
      end

      { old_state: old_state, new_state: new_state, changed: old_state && old_state != new_state }
    end
  end
end
