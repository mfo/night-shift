# frozen_string_literal: true

require 'json'
require 'open3'
require 'set'

module Nightshift
  module Integrations
    #
    # FlakyCiScanner — Backlog builder from GitHub Actions flaky test detection
    #
    # Analyzes recent CI failures to identify flaky tests using two signals:
    #   1. Merge queue failures (gh-readonly-queue/* branches) — code already
    #      approved, so failures are pure infrastructure/flaky signal
    #   2. Retry analysis — run_attempt > 1 where retried job passed
    #
    # Returns [{item:, priority:, context:}] for reconcile_backlog.
    #
    module FlakyCiScanner
      module_function

      WORKFLOW_NAME = 'Continuous Integration'

      def scan(repo_path)
        repo = detect_repo(repo_path)
        runs = fetch_failed_runs(repo, limit: 200)
        return [] if runs.empty?

        failures = analyze_runs(repo, runs)
        return [] if failures.empty?

        flaky_specs = extract_flaky_specs(repo, failures)
        return [] if flaky_specs.empty?

        flaky_specs.map do |spec_file, data|
          {
            item: spec_file,
            priority: calculate_priority(data),
            context: JSON.generate(data)
          }
        end
      end

      def detect_repo(repo_path)
        out, _, status = Open3.capture3('gh', 'repo', 'view', '--json', 'nameWithOwner',
                                        '--jq', '.nameWithOwner', chdir: repo_path)
        abort 'nightshift: cannot detect repo (gh repo view failed)' unless status.success?
        out.strip
      end

      def fetch_failed_runs(repo, limit:)
        runs = []
        pages = (limit / 100.0).ceil

        pages.times do |page|
          data = gh_api("repos/#{repo}/actions/runs?per_page=100&page=#{page + 1}&status=failure")
          break unless data

          ci_runs = (data['workflow_runs'] || []).select { |r| r['name'] == WORKFLOW_NAME }
          runs.concat(ci_runs)
          break if runs.size >= limit
        end

        runs.first(limit)
      end

      def analyze_runs(repo, runs)
        failures = []

        runs.each do |run|
          data = gh_api("repos/#{repo}/actions/runs/#{run['id']}/jobs")
          next unless data

          failed_jobs = (data['jobs'] || []).select { |j| j['conclusion'] == 'failure' }
          next if failed_jobs.empty?

          merge_queue = run['head_branch'].start_with?('gh-readonly-queue/')

          failed_jobs.each do |job|
            category = categorize(job['name'])
            next unless %i[unit system].include?(category)

            failures << {
              run_id: run['id'],
              branch: run['head_branch'],
              attempt: run['run_attempt'],
              job_id: job['id'],
              job_name: job['name'],
              category: category,
              merge_queue: merge_queue
            }
          end
        end

        failures
      end

      def extract_flaky_specs(repo, failures)
        by_spec = Hash.new { |h, k| h[k] = { merge_queue_count: 0, retry_count: 0, branches: Set.new, jobs: Set.new } }

        failures.each do |f|
          specs = extract_specs_from_log(repo, f[:job_id])
          next if specs.empty?

          specs.each do |spec|
            data = by_spec[spec]
            data[:merge_queue_count] += 1 if f[:merge_queue]
            data[:retry_count] += 1 if f[:attempt] > 1
            data[:branches] << f[:branch]
            data[:jobs] << f[:job_name]
          end
        end

        by_spec.each_value do |data|
          data[:branches] = data[:branches].to_a
          data[:jobs] = data[:jobs].to_a
        end

        by_spec.select { |_, data| data[:merge_queue_count] > 0 || data[:retry_count] > 0 }
      end

      def extract_specs_from_log(repo, job_id)
        out, _, status = Open3.capture3('gh', 'api', "repos/#{repo}/actions/jobs/#{job_id}/logs")
        return [] unless status.success?

        out.scan(%r{rspec \./spec/\S+}).map { |s| s.sub(/\e\[[0-9;]*m.*/, '').strip }.uniq
      end

      def categorize(job_name)
        case job_name
        when /system/i then :system
        when /unit/i then :unit
        when /lint/i then :linter
        else :other
        end
      end

      def calculate_priority(data)
        mq = data[:merge_queue_count]
        retries = data[:retry_count]
        score = mq * 3 + retries

        case score
        when 15.. then 10
        when 10..14 then 8
        when 6..9 then 6
        when 3..5 then 4
        when 1..2 then 2
        else 0
        end
      end

      def gh_api(path)
        out, _, status = Open3.capture3('gh', 'api', path)
        return nil unless status.success?

        JSON.parse(out)
      end
    end
  end
end
