require "open3"
require "json"

module Nightshift
  module GitHub
    module_function

    # Fetch all PRs for the current user via a single GraphQL query
    # + deployed PRs from releases (REST)
    # Returns Array<PR>
    def fetch_prs
      repo = gh_repo
      gh_user = ENV.fetch("NIGHTSHIFT_USER")

      raw_prs = fetch_prs_graphql(repo, gh_user)
      deployed_numbers = fetch_deployed_prs(repo)

      raw_prs.map do |data|
        data[:deployed] = deployed_numbers.include?(data[:number])
        PR.new(**data)
      end
    end

    # Fetch PR numbers deployed in recent releases (last 5)
    def fetch_deployed_prs(repo = gh_repo)
      output = capture("gh", "api", "repos/#{repo}/releases?per_page=5", "--jq", ".[].body")
      output.scan(/#(\d+)/).flatten.map(&:to_i).uniq
    end

    # --- Single GraphQL query ---

    def fetch_prs_graphql(repo, gh_user)
      owner, name = repo.split("/")
      query = <<~GQL
        {
          repository(owner: "#{owner}", name: "#{name}") {
            pullRequests(first: 100, states: [OPEN, MERGED, CLOSED], orderBy: {field: UPDATED_AT, direction: DESC}) {
              nodes {
                number
                headRefName
                state
                updatedAt
                author { login }
                autoMergeRequest { enabledAt }
                reviewDecision
                reviews(last: 10) {
                  nodes { state author { login } }
                }
                reviewThreads(first: 100) {
                  nodes { isResolved }
                }
                comments { totalCount }
                commits(last: 1) {
                  nodes {
                    commit {
                      statusCheckRollup {
                        contexts(first: 100) {
                          nodes {
                            ... on CheckRun { conclusion status }
                            ... on StatusContext { state }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      GQL

      output = capture("gh", "api", "graphql", "-f", "query=#{query}")
      data = JSON.parse(output, symbolize_names: true)
      nodes = data.dig(:data, :repository, :pullRequests, :nodes) || []

      nodes.filter_map do |node|
        next unless node.dig(:author, :login) == gh_user
        parse_pr_node(node)
      end
    end

    def parse_pr_node(node)
      # CI status from last commit's statusCheckRollup
      contexts = node.dig(:commits, :nodes, 0, :commit, :statusCheckRollup, :contexts, :nodes) || []
      ci = derive_ci(contexts)

      # Reviews: find last reviewer
      reviews = node.dig(:reviews, :nodes) || []
      relevant = reviews.select { |r| %w[COMMENTED CHANGES_REQUESTED APPROVED].include?(r[:state]) }
      reviewer = relevant.last&.dig(:author, :login) || ""

      # Unresolved review threads
      threads = node.dig(:reviewThreads, :nodes) || []
      unresolved_count = threads.count { |t| !t[:isResolved] }

      # review_count: prefer unresolved threads, fallback to review count
      review_count = unresolved_count > 0 ? unresolved_count : relevant.size

      # Issue comments count
      comment_count = node.dig(:comments, :totalCount) || 0

      {
        number: node[:number],
        branch: node[:headRefName],
        github_state: node[:state],
        ci: ci,
        review_decision: node[:reviewDecision] || "",
        review_count: review_count,
        comment_count: comment_count,
        auto_merge: !node[:autoMergeRequest].nil?,
        reviewer: reviewer,
        updated_at: node[:updatedAt]
      }
    end

    def derive_ci(contexts)
      return "none" if contexts.empty?

      statuses = contexts.map do |c|
        if c[:conclusion]
          # CheckRun
          { conclusion: c[:conclusion], status: c[:status] }
        elsif c[:state]
          # StatusContext
          case c[:state]
          when "SUCCESS" then { conclusion: "SUCCESS", status: "COMPLETED" }
          when "FAILURE" then { conclusion: "FAILURE", status: "COMPLETED" }
          when "ERROR"   then { conclusion: "ERROR",   status: "COMPLETED" }
          when "PENDING" then { conclusion: nil,       status: "PENDING" }
          else                { conclusion: nil,       status: c[:state] }
          end
        else
          { conclusion: nil, status: nil }
        end
      end

      if statuses.all? { |s| s[:conclusion] == "SUCCESS" }
        "green"
      elsif statuses.any? { |s| %w[FAILURE ERROR TIMED_OUT].include?(s[:conclusion]) }
        "red"
      elsif statuses.any? { |s| %w[IN_PROGRESS QUEUED PENDING].include?(s[:status]) }
        "running"
      else
        "unknown"
      end
    end

    def gh_repo
      repo_path = ENV.fetch("NIGHTSHIFT_REPO")
      capture("gh", "repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner",
              chdir: repo_path).strip
    end

    class Error < StandardError; end

    def capture(*cmd, chdir: nil)
      opts = chdir ? { chdir: chdir } : {}
      out, err, status = Open3.capture3(*cmd, **opts)
      unless status.success?
        msg = "nightshift: command failed: #{cmd.join(' ')}"
        msg += "\n#{err}" unless err.empty?
        raise Error, msg
      end
      out
    end
  end
end
