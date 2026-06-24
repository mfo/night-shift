# frozen_string_literal: true

module Nightshift
  module Core
    #
    # PR — Pull request domain model
    #
    # Computes a prioritized state (PRState enum) from raw GitHub fields
    # (CI status, review decision, merge state, deploy status).
    # Provides display helpers: emoji badges, tmux window names, slugs.
    #
    class PR
      EMOJI = {
        PRState::Deployed => '🚀', PRState::Merged => '🗑', PRState::Closed => '⊘',
        PRState::CiRed => '🔴', PRState::ChangesRequested => '⛔',
        PRState::AutoMerging => '🔀', PRState::Approved => '✅',
        PRState::HasComments => '💬', PRState::CiGreen => '🟢',
        PRState::CiRunning => '⏳', PRState::Draft => '◯'
      }.freeze

      attr_accessor :number, :branch, :github_state, :ci,
                    :review_decision, :review_count, :comment_count,
                    :auto_merge, :deployed, :updated_at, :reviewer

      def initialize(**attrs)
        attrs.each { |k, v| send(:"#{k}=", v) }
      end

      # Priority order (first match wins):
      # terminal: deployed > merged > closed
      # urgent:   ci_red > changes_requested
      # active:   auto_merging > approved > has_comments
      # passive:  ci_green > ci_running > draft
      def state
        case to_h
        in { github_state: 'MERGED', deployed: true }  then PRState::Deployed
        in { github_state: 'MERGED' }                  then PRState::Merged
        in { github_state: 'CLOSED' }                  then PRState::Closed
        in { ci: 'red' }                               then PRState::CiRed
        in { review_decision: 'CHANGES_REQUESTED' }    then PRState::ChangesRequested
        in { auto_merge: true }                        then PRState::AutoMerging
        in { review_decision: 'APPROVED' }             then PRState::Approved
        in { review_count: (1..) }                     then PRState::HasComments
        in { ci: 'green' }                             then PRState::CiGreen
        in { ci: 'running' }                           then PRState::CiRunning
        else                                                PRState::Draft
        end
      end

      def emoji       = EMOJI[state]
      def slug        = branch&.sub(%r{^(US|fix|feat|tech)/}, '')&.slice(0, 35)
      def window_name = number ? "#{emoji} ##{number} #{slug}" : "🔨 #{slug}"

      def badge
        return emoji if [PRState::Deployed, PRState::Merged, PRState::Closed].include?(state)

        ci_badge = { 'red' => '🔴', 'green' => '🟢', 'running' => '⏳' }[ci] || '◯'
        review_badge = case review_decision
                       when 'APPROVED' then '✅'
                       when 'CHANGES_REQUESTED' then '⛔'
                       else review_count.to_i.positive? ? "💬(#{review_count})" : ''
                       end
        "#{ci_badge}#{review_badge}"
      end

      def to_h
        { github_state:, ci:, review_decision:, review_count:,
          auto_merge:, deployed: }
      end

      def to_db_hash
        {
          number:, branch:, state: state.serialize, github_state:, ci:,
          review_decision:, review_count: review_count.to_i,
          comment_count: comment_count.to_i,
          auto_merge: auto_merge ? true : false,
          deployed: deployed ? true : false,
          reviewer:, updated_at:, synced_at: Time.now.to_i
        }
      end

      def self.from_db(row)
        new(
          number: row[:number], branch: row[:branch],
          github_state: row[:github_state], ci: row[:ci],
          review_decision: row[:review_decision],
          review_count: row[:review_count],
          comment_count: row[:comment_count],
          auto_merge: row[:auto_merge], deployed: row[:deployed],
          reviewer: row[:reviewer], updated_at: row[:updated_at]
        )
      end
    end
  end
end
