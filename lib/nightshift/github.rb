require "open3"

module Nightshift
  module GitHub
    module_function

    # Fetch all PRs for the current user, merging 3 passes:
    # Pass 1: lightweight (all PRs by author)
    # Pass 2: rich (open PRs — CI, reviews, auto_merge)
    # Pass 3: GraphQL (unresolved review threads)
    # Returns Array<PR>
    def fetch_prs
      repo = gh_repo
      gh_user = ENV.fetch("NIGHTSHIFT_USER")

      all_prs = fetch_all_lightweight(repo, gh_user)
      rich_prs = fetch_open_rich(repo)
      unresolved = fetch_unresolved_threads(repo)
      deployed_numbers = fetch_deployed_prs(repo)

      merge_passes(all_prs, rich_prs, unresolved, deployed_numbers)
    end

    # Fetch PR numbers deployed in recent releases (last 5)
    def fetch_deployed_prs(repo = gh_repo)
      output = capture("gh", "api", "repos/#{repo}/releases?per_page=5", "--jq", ".[].body")
      output.scan(/#(\d+)/).flatten.map(&:to_i).uniq
    end

    # --- private helpers ---

    # Pass 1: all user PRs (lightweight)
    # Returns Hash { branch => { number:, state: } }
    def fetch_all_lightweight(repo, gh_user)
      jq = %([.[] | select(.author.login == "#{gh_user}")] | .[] | "\\(.headRefName)|\\(.number)|\\(.state)")
      output = capture("gh", "pr", "list",
                        "--repo", repo, "--state", "all", "--limit", "200",
                        "--json", "number,headRefName,state,author",
                        "--jq", jq)
      result = {}
      output.each_line do |line|
        fields = line.strip.split("|")
        next if fields.size < 3
        branch, number, state = fields
        result[branch] = { number: number.to_i, state: state }
      end
      result
    end

    # Pass 2: open PRs with CI + reviews
    # Returns Hash { branch => raw_fields_hash }
    def fetch_open_rich(repo)
      jq = <<~JQ.gsub("\n", " ").strip
        .[] | "\\(.headRefName)|\\(.number)|\\(.state)|\\(
          if (.statusCheckRollup | length) == 0 then "none"
          elif (.statusCheckRollup | all(.conclusion == "SUCCESS")) then "green"
          elif (.statusCheckRollup | any(.conclusion == "FAILURE" or .conclusion == "ERROR" or .conclusion == "TIMED_OUT")) then "red"
          elif (.statusCheckRollup | any(.status == "IN_PROGRESS" or .status == "QUEUED" or .status == "PENDING")) then "running"
          else "unknown"
          end
        )|\\([.reviews[] | select(.state == "COMMENTED" or .state == "CHANGES_REQUESTED" or .state == "APPROVED")] | length)|\\(.reviewDecision // "")|\\(.updatedAt)|\\(
          [.reviews[] | select(.state == "APPROVED" or .state == "CHANGES_REQUESTED" or .state == "COMMENTED")] | last | .author.login // ""
        )|\\(if .autoMergeRequest != null then "auto" else "" end)"
      JQ
      output = capture("gh", "pr", "list",
                        "--repo", repo, "--state", "open", "--limit", "50",
                        "--json", "number,headRefName,state,statusCheckRollup,reviewDecision,reviews,updatedAt,autoMergeRequest",
                        "--jq", jq)
      result = {}
      output.each_line do |line|
        fields = line.strip.split("|")
        next if fields.size < 8
        branch = fields[0]
        result[branch] = {
          number: fields[1].to_i, state: fields[2], ci: fields[3],
          review_count: fields[4].to_i, review_decision: fields[5],
          updated_at: fields[6], reviewer: fields[7],
          auto_merge: fields[8] == "auto"
        }
      end
      result
    end

    # Pass 3: unresolved review threads via GraphQL
    # Returns Hash { branch => unresolved_count }
    def fetch_unresolved_threads(repo)
      owner, name = repo.split("/")
      query = <<~GQL
        { repository(owner:"#{owner}", name:"#{name}") {
          pullRequests(first:50, states:OPEN, orderBy:{field:UPDATED_AT, direction:DESC}) {
            nodes { number headRefName
              reviewThreads(first:100) { nodes { isResolved } }
            }
          }
        }}
      GQL
      jq = '.data.repository.pullRequests.nodes[] | "\(.headRefName)|\([.reviewThreads.nodes[] | select(.isResolved == false)] | length)"'
      output = capture("gh", "api", "graphql", "-f", "query=#{query}", "--jq", jq)
      result = {}
      output.each_line do |line|
        branch, count = line.strip.split("|")
        result[branch] = count.to_i if branch
      end
      result
    end

    # Merge 3 passes into Array<PR>
    def merge_passes(all_prs, rich_prs, unresolved, deployed_numbers)
      all_prs.map do |branch, lightweight|
        if (rich = rich_prs[branch])
          review_count = unresolved.fetch(branch, rich[:review_count])
          PR.new(
            number: rich[:number], branch: branch,
            github_state: rich[:state], ci: rich[:ci],
            review_decision: rich[:review_decision],
            review_count: review_count,
            auto_merge: rich[:auto_merge],
            deployed: deployed_numbers.include?(rich[:number]),
            reviewer: rich[:reviewer],
            updated_at: rich[:updated_at]
          )
        else
          PR.new(
            number: lightweight[:number], branch: branch,
            github_state: lightweight[:state], ci: "none",
            review_count: 0,
            deployed: deployed_numbers.include?(lightweight[:number])
          )
        end
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
