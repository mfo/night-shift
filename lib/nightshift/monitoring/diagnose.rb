require "open3"

module Nightshift
  module Diagnose
    module_function

    def run(pr_number)
      repo = GitHub.gh_repo

      puts "── CI DIAGNOSTIC — PR ##{pr_number} ──────────────────────"
      puts ""

      # Get latest CI run
      run_id = extract_run_id(repo, pr_number)
      unless run_id
        puts "  no CI run found"
        return
      end

      # Get all failed jobs
      failed_jobs = fetch_failed_jobs(repo, run_id)
      if failed_jobs.empty?
        puts "  ✅ no failed jobs"
        return
      end

      has_linter_failure = false

      failed_jobs.each do |job_id, job_name|
        category, action = categorize_job(job_name, job_id)
        has_linter_failure = true if category == "🧹 LINTER"

        puts "  #{category} — #{job_name}"
        puts "  → #{action}"

        logs = fetch_logs(repo, job_id)
        unless logs
          puts "  ⚠ could not fetch logs"
          puts ""
          next
        end

        print_diagnostics(job_name, logs)
        puts ""
      end

      if has_linter_failure
        puts "  💡 Linter failures detected — run: nightshift autofix"
        puts ""
      end
    end

    def extract_run_id(repo, pr_number)
      out = GitHub.capture("gh", "pr", "checks", pr_number.to_s,
                           "--repo", repo, "--json", "link", "--jq", ".[0].link")
      match = out.match(/runs\/(\d+)/)
      match&.captures&.first
    end

    def fetch_failed_jobs(repo, run_id)
      out = GitHub.capture("gh", "api", "repos/#{repo}/actions/runs/#{run_id}/jobs",
                           "--jq", '.jobs[] | select(.conclusion == "failure") | "\(.id)|\(.name)"')
      out.each_line.filter_map do |line|
        id, name = line.strip.split("|", 2)
        [id, name] if id && name
      end
    end

    def categorize_job(job_name, job_id)
      case job_name
      when /CodeQL|codeql/i
        ["🔒 SECURITY", "review manuelle requise"]
      when /System|system/i
        ["🧪 SYSTEM TEST", "retry recommandé: gh run rerun --job #{job_id}"]
      when /Unit|unit/i
        ["🧪 UNIT TEST", "specs à fixer"]
      when /Lint|lint/i
        ["🧹 LINTER", "autofix dispo"]
      else
        ["❓ OTHER", "voir logs"]
      end
    end

    def fetch_logs(repo, job_id)
      out = GitHub.capture("gh", "api", "repos/#{repo}/actions/jobs/#{job_id}/logs")
      out.empty? ? nil : out
    end

    def print_diagnostics(job_name, logs)
      clean = strip_ansi(logs)

      case job_name
      when /Lint|lint/i
        offenses = clean.lines.grep(/\.(rb|erb|haml):\d+.*[CWEF]:/).first(10)
        offenses.each { |l| puts "  #{l.sub(/^.*Z /, '').strip}" }
        summary = clean.lines.grep(/offenses? detected|autocorrectable/).last
        puts "  #{summary.sub(/^.*Z /, '').strip}" if summary
        puts ""
        puts "  FIX: bundle exec rubocop -a"
        puts "       bun lint:herb --fix"
        puts "       bundle exec rake lint:apostrophe:fix"
        puts "       bundle exec rake lint:yaml_newline:fix"

      when /Unit|unit|System|system/i
        failures = clean.lines.grep(/rspec \.\/spec\//).first(10)
        failures.each { |l| puts "  #{l.sub(/^.*rspec /, 'rspec ').strip}" }
        descriptions = clean.lines.grep(/Failure\/Error:|expected:.*got:/).first(10)
        descriptions.each { |l| puts "  #{l.sub(/^.*Z\s*/, '').strip}" }
        summary = clean.lines.grep(/\d+ examples?, \d+ failures?/).last
        puts "  #{summary.sub(/^.*Z /, '').strip}" if summary

      when /CodeQL|codeql/i
        puts "  ⚠ CodeQL findings — check GitHub Security tab"
      end
    end

    def strip_ansi(text)
      text.gsub(/\e\[[0-9;]*m/, "")
    end
  end
end
