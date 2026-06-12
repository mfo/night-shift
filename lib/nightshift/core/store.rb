# frozen_string_literal: true

module Nightshift
  module Core
    #
    # Store — SQLite persistence layer
    #
    # Central data access for all persisted state: PRs, backlog items,
    # autolearn cycles, state transitions, runs (locks + circuit breakers),
    # infra suggestions, and key-value settings.
    #
    # Uses Sequel with WAL mode. Row hashes are converted to typed structs
    # (BacklogItem, AutolearnCycle) at the boundary via .from_row.
    #
    class Store
      extend T::Sig

      # Frozen serialized constants — avoids repeated .serialize in hot paths
      PENDING_S  = BacklogStatus::Pending.serialize.freeze
      RUNNING_S  = BacklogStatus::Running.serialize.freeze
      PR_OPEN_S  = BacklogStatus::PrOpen.serialize.freeze
      DONE_S     = BacklogStatus::Done.serialize.freeze
      ACTIVE_STATUSES = [RUNNING_S, PR_OPEN_S].freeze

      attr_reader :db

      sig { params(db: Sequel::Database).void }
      def initialize(db = Nightshift.db)
        @db = db
      end

      sig { params(pr: Core::PR).void }
      def upsert(pr)
        db[:prs].insert_conflict(target: :number, update: {
                                   branch: pr.branch, state: pr.state.serialize, github_state: pr.github_state,
                                   ci: pr.ci, review_decision: pr.review_decision,
                                   review_count: pr.review_count.to_i, comment_count: pr.comment_count.to_i,
                                   auto_merge: pr.auto_merge ? true : false,
                                   deployed: pr.deployed ? true : false, reviewer: pr.reviewer,
                                   updated_at: pr.updated_at, synced_at: Time.now.to_i
                                 }).insert(pr.to_db_hash)
      end

      sig { params(pr_number: Integer).returns(T.nilable(PRState)) }
      def get_state(pr_number)
        row = db[:prs].where(number: pr_number).first
        row&.dig(:state)&.then { |s| PRState.deserialize(s) }
      end

      sig { params(pr_number: Integer, from: PRState, to: PRState).void }
      def record_transition(pr_number, from, to)
        db[:transitions].insert(
          pr_number: pr_number, from_state: from.serialize,
          to_state: to.serialize, created_at: Time.now.to_i
        )
      end

      sig { params(pr_number: Integer, kind: String, max: Integer, window: Integer).returns(T::Boolean) }
      def circuit_breaker?(pr_number, kind: 'autofix',
                           max: ENV.fetch('NIGHTSHIFT_AUTOFIX_MAX').to_i,
                           window: ENV.fetch('NIGHTSHIFT_AUTOFIX_WINDOW').to_i)
        db[:runs]
          .where(pr_number: pr_number, kind: kind)
          .where { created_at > Time.now.to_i - window }
          .count >= max
      end

      sig { params(pr_number: Integer, kind: String).void }
      def record_run(pr_number, kind:)
        now = Time.now.to_i
        db[:runs].insert(pr_number: pr_number, kind: kind,
                         created_at: now, started_at: now, finished_at: now)
      end

      sig { params(pr_number: Integer, kind: String, timeout: Integer).returns(T::Boolean) }
      def locked?(pr_number, kind:, timeout: 900)
        expire_zombies(kind: kind, timeout: timeout)
        active_lock?(pr_number, kind: kind)
      end

      sig { params(pr_number: Integer, kind: String, timeout: Integer, blk: T.proc.params(result: T::Hash[Symbol, T.untyped]).void).returns(T::Boolean) }
      def with_lock(pr_number, kind:, timeout: 900, &blk)
        return false unless acquire_lock(pr_number, kind: kind, timeout: timeout)

        result = { success: nil }
        begin
          yield result
          result[:success] = true if result[:success].nil?
        rescue StandardError
          result[:success] = false
          raise
        ensure
          release_lock(pr_number, kind: kind, **result)
        end
        true
      end

      sig { params(pr_number: Integer, kind: String, timeout: Integer).returns(T::Boolean) }
      def acquire_lock(pr_number, kind:, timeout: 900)
        db.transaction do
          expire_zombies(kind: kind, timeout: timeout)
          return false if active_lock?(pr_number, kind: kind)

          db[:runs].insert(
            pr_number: pr_number, kind: kind,
            created_at: Time.now.to_i, started_at: Time.now.to_i,
            finished_at: nil, success: nil
          )
          true
        end
      end

      sig { params(pr_number: Integer, kind: String, success: T.nilable(T::Boolean), extras: T.untyped).void }
      def release_lock(pr_number, kind:, success: nil, **extras)
        updates = { finished_at: Time.now.to_i, success: success }
        updates.merge!(extras)
        db[:runs].where(pr_number: pr_number, kind: kind, finished_at: nil)
                 .update(updates)
      end

      sig { params(key: String).returns(T.nilable(String)) }
      def get_setting(key)
        db[:settings].where(key: key).get(:value)
      end

      sig { params(key: String, value: String).void }
      def set_setting(key, value)
        db[:settings].insert_conflict(target: :key, update: { value: value.to_s })
                     .insert(key: key, value: value.to_s)
      end

      # --- Backlog ---

      sig { params(skill: String, item: String, priority: Integer, context: T.nilable(String)).void }
      def add_backlog(skill, item, priority: 0, context: nil)
        now = Time.now.to_i
        db[:backlog_items].insert_conflict(target: %i[skill item])
                          .insert(skill: skill, item: item, status: PENDING_S,
                                  priority: priority, context: context,
                                  created_at: now, updated_at: now)
      end

      sig { params(id: Integer, priority: Integer).void }
      def update_backlog_priority(id, priority)
        db[:backlog_items].where(id: id).update(priority: priority, updated_at: Time.now.to_i)
      end

      sig { params(skill: String).returns(T.nilable(BacklogItem)) }
      def claim_next(skill)
        db.transaction do
          row = db[:backlog_items]
                .where(skill: skill, status: PENDING_S)
                .where { (retry_after =~ nil) | (retry_after < Time.now.to_i) }
                .order(Sequel.desc(:priority), :created_at)
                .first
          return nil unless row

          rows = db[:backlog_items]
                 .where(id: row[:id], status: PENDING_S)
                 .update(status: RUNNING_S, updated_at: Time.now.to_i)
          rows == 1 ? BacklogItem.from_row(row.merge(status: RUNNING_S)) : nil
        end
      end

      sig { params(skill: String).returns(T::Boolean) }
      def active_for_skill?(skill)
        db[:backlog_items]
          .where(skill: skill, status: ACTIVE_STATUSES)
          .count.positive?
      end

      sig { params(backlog_item: BacklogItem, status: BacklogStatus, extras: T.untyped).void }
      def update_backlog_status(backlog_item, status, **extras)
        updates = { status: status.serialize, updated_at: Time.now.to_i }
        extras.each { |k, v| updates[k] = v.is_a?(T::Enum) ? v.serialize : v }
        db[:backlog_items].where(id: backlog_item.id).update(updates)
      end

      sig { params(branch: String).returns(T.nilable(BacklogItem)) }
      def backlog_by_branch(branch)
        row = db[:backlog_items].where(branch: branch).first
        row ? BacklogItem.from_row(row) : nil
      end

      sig { params(skill: T.nilable(String)).returns(T::Array[BacklogItem]) }
      def all_backlog(skill: nil)
        ds = db[:backlog_items]
        ds = ds.where(skill: skill) if skill
        ds.order(:skill, :created_at).all.map { |row| BacklogItem.from_row(row) }
      end

      sig { params(id: T.any(Integer, String)).returns(T.nilable(BacklogItem)) }
      def get_backlog_item(id)
        row = db[:backlog_items].where(id: id.to_i).first
        row ? BacklogItem.from_row(row) : nil
      end

      sig { params(backlog_item: BacklogItem).returns(T::Array[AutolearnCycle]) }
      def cycles_for_item(backlog_item)
        db[:autolearn_cycles]
          .where(backlog_item_id: backlog_item.id)
          .order(:attempt)
          .all.map { |row| AutolearnCycle.from_row(row) }
      end

      sig { params(backlog_item: BacklogItem).void }
      def retry_backlog_item(backlog_item)
        db[:backlog_items].where(id: backlog_item.id)
                          .update(status: PENDING_S, retry_count: 0,
                                  last_verdict: nil, failure_reason: nil, branch: nil,
                                  retry_after: nil, updated_at: Time.now.to_i)
      end

      # --- Infra suggestions ---

      sig { params(skill: String, description: String, source: String, target: T.nilable(String), backlog_item_id: T.nilable(Integer)).returns(Integer) }
      def add_infra_suggestion(skill:, description:, source:, target: nil, backlog_item_id: nil)
        # Dedup: si la meme suggestion existe deja en pending, incrementer le compteur
        existing = db[:infra_suggestions]
                   .where(skill: skill, description: description, status: 'pending')
                   .first
        if existing
          db[:infra_suggestions].where(id: existing[:id])
                                .update(occurrences: Sequel.expr(:occurrences) + 1)
          return existing[:id]
        end

        db[:infra_suggestions].insert(
          skill: skill, source: source, description: description,
          target: target, backlog_item_id: backlog_item_id,
          occurrences: 1, status: 'pending', created_at: Time.now.to_i
        )
      end

      sig { params(skill: T.nilable(String)).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def pending_infra_suggestions(skill: nil)
        ds = db[:infra_suggestions].where(status: 'pending')
        ds = ds.where(skill: skill) if skill
        ds.order(Sequel.desc(:occurrences), :created_at).all
      end

      sig { params(id: Integer, status: String).void }
      def resolve_infra_suggestion(id, status:)
        db[:infra_suggestions].where(id: id)
                              .update(status: status, resolved_at: Time.now.to_i)
      end

      # --- PRs ---

      sig { params(github_state: T.nilable(String)).returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def all_prs(github_state: nil)
        ds = db[:prs]
        ds = ds.where(github_state: github_state) if github_state
        ds.all
      end

      sig { params(ttl: Integer).returns(T::Boolean) }
      def fresh?(ttl: 60)
        synced = db[:prs].max(:synced_at)
        return false unless synced

        (Time.now.to_i - synced.to_i) < ttl
      end

      sig { params(pr: Core::PR).returns(T::Hash[Symbol, T.untyped]) }
      def reconcile_pr(pr)
        old_state = get_state(pr.number)
        old_comment_count = get_comment_count(pr.number)
        new_state = pr.state

        db.transaction do
          upsert(pr)
          record_transition(pr.number, old_state, new_state) if old_state && old_state != new_state
        end

        comment_delta = old_comment_count ? (pr.comment_count.to_i - old_comment_count) : 0

        { old_state: old_state, new_state: new_state,
          changed: old_state && old_state != new_state,
          comment_delta: [comment_delta, 0].max }
      end

      sig { params(pr_number: Integer).returns(T.nilable(Integer)) }
      def get_comment_count(pr_number)
        row = db[:prs].where(number: pr_number).first
        row&.dig(:comment_count)
      end

      private

      def expire_zombies(kind:, timeout:)
        db[:runs].where(kind: kind, finished_at: nil)
                 .exclude(started_at: nil)
                 .where { started_at < Time.now.to_i - timeout }
                 .update(finished_at: -1, success: false)
      end

      def active_lock?(pr_number, kind:)
        db[:runs]
          .where(pr_number: pr_number, kind: kind, finished_at: nil)
          .exclude(started_at: nil)
          .count.positive?
      end
    end
  end
end
