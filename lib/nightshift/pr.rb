module Nightshift
  class PR
    STATES = %i[deployed merged closed ci_red changes_requested
                auto_merging approved has_comments ci_green
                ci_running draft].freeze

    EMOJI = {
      deployed: "🚀", merged: "🗑", closed: "⊘", ci_red: "🔴",
      changes_requested: "⛔", auto_merging: "🔀", approved: "✅",
      has_comments: "💬", ci_green: "🟢", ci_running: "⏳", draft: "◯"
    }.freeze

    attr_accessor :number, :branch, :github_state, :ci,
                  :review_decision, :review_count, :auto_merge,
                  :deployed, :updated_at, :reviewer

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
      in { github_state: "MERGED", deployed: true }  then :deployed
      in { github_state: "MERGED" }                  then :merged
      in { github_state: "CLOSED" }                  then :closed
      in { ci: "red" }                               then :ci_red
      in { review_decision: "CHANGES_REQUESTED" }    then :changes_requested
      in { auto_merge: true }                        then :auto_merging
      in { review_decision: "APPROVED" }             then :approved
      in { review_count: (1..) }                     then :has_comments
      in { ci: "green" }                             then :ci_green
      in { ci: "running" }                           then :ci_running
      else                                                :draft
      end
    end

    def emoji       = EMOJI[state]
    def slug        = branch&.sub(%r{^(US|fix|feat|tech)/}, "")&.slice(0, 35)
    def window_name = number ? "#{emoji} ##{number} #{slug}" : "🔨 #{slug}"

    def badge
      return emoji if %i[deployed merged closed].include?(state)
      ci_badge = { "red" => "🔴", "green" => "🟢", "running" => "⏳" }[ci] || "◯"
      review_badge = case review_decision
                     when "APPROVED" then "✅"
                     when "CHANGES_REQUESTED" then "⛔"
                     else review_count.to_i > 0 ? "💬(#{review_count})" : ""
                     end
      "#{ci_badge}#{review_badge}"
    end

    def to_h
      { github_state:, ci:, review_decision:, review_count:,
        auto_merge:, deployed: }
    end

    def to_db_hash
      {
        number:, branch:, state: state.to_s, github_state:, ci:,
        review_decision:, review_count: review_count.to_i,
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
        auto_merge: row[:auto_merge], deployed: row[:deployed],
        reviewer: row[:reviewer], updated_at: row[:updated_at]
      )
    end
  end
end
