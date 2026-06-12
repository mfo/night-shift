# frozen_string_literal: true

require 'open3'

module Nightshift
  module CI
    #
    # Autofix — Automated CI unblocking
    #
    # When a PR goes red, Autofix analyzes failed jobs and applies
    # fixes by category:
    #   1. System tests → retry (flaky, 1 max)
    #   2. Unit specs   → claude -p (Read/Edit/rspec, max 20 turns)
    #   3. Linters      → rubocop -A, herb, apostrophe, yaml
    #   4. Verify       → re-run specs + linters to confirm
    #
    # Commit and push remain manual.
    # Built-in circuit breaker (max N runs per time window).
    #
    module Autofix
      extend T::Sig
      module_function

      sig { params(pr_number: Integer, store: Core::Store).void }
      def run(pr_number, store:)
        repo = Integrations::GitHub.gh_repo

        puts "── AUTOFIX — PR ##{pr_number} ──────────────────────"

        # Circuit breaker
        if store.circuit_breaker?(pr_number.to_i, kind: 'ci_red')
          puts '  ⛔ circuit breaker: max autofix attempts reached, skipping'
          return
        end

        store.with_lock(pr_number.to_i, kind: 'ci_red') do |result|
          run_pipeline(pr_number, store: store, repo: repo, result: result)
        end || puts('  ⏳ autofix already running, skipping')
      end

      sig { params(pr_number: Integer, store: Core::Store, repo: String, result: T::Hash[Symbol, T.untyped]).void }
      def run_pipeline(pr_number, store:, repo:, result: {})
        # Resolve worktree path: use the PR's worktree if it exists, fallback to main repo
        base_repo = Nightshift.repo_path
        row = store.db[:prs].where(number: pr_number.to_i).first
        branch = row&.dig(:branch)
        repo_path = (branch && Integrations::Worktree.path_for_branch(branch, base_repo)) || base_repo

        # Get latest CI run
        run_id = Monitoring::Diagnose.extract_run_id(repo, pr_number)
        unless run_id
          puts '  no CI run found'
          return
        end

        # Categorize failures
        failed_jobs = Monitoring::Diagnose.fetch_failed_jobs(repo, run_id)
        has_linter = false
        has_specs = false
        has_codeql = false
        system_test_jobs = []
        failed_spec_files = []

        failed_jobs.each do |job_id, job_name|
          case job_name
          when /Lint|lint/i then has_linter = true
          when /CodeQL|codeql/i then has_codeql = true
          when /System|system/i then system_test_jobs << [job_id, job_name]
          when /Unit|unit/i
            has_specs = true
            logs = Monitoring::Diagnose.fetch_logs(repo, job_id)
            if logs
              clean = Monitoring::Diagnose.strip_ansi(logs)
              clean.lines.grep(%r{rspec \./spec/}).each do |l|
                failed_spec_files << l.sub(/^.*rspec /, 'rspec ').strip
              end
            end
          end
        end

        unless has_linter || has_specs || system_test_jobs.any? || has_codeql
          puts '  ✋ nothing to autofix'
          puts "  use 'nightshift diagnose' for full diagnostic"
          return
        end

        # Dashboard
        st = {
          linter: has_linter ? '🔴' : '⚫',
          unit: has_specs ? '🔴' : '⚫',
          codeql: has_codeql ? '🔴' : '⚫',
          system: system_test_jobs.any? ? '🔴' : '⚫'
        }
        print_dashboard(st)

        logdir = File.join(repo_path, 'tmp')
        FileUtils.mkdir_p(logdir)

        # Step 1: System test retry
        if system_test_jobs.any?
          puts ''
          puts '  → retrying system tests ...'
          if store.circuit_breaker?(pr_number.to_i, kind: 'retry', max: 1)
            puts '  ⛔ already retried once — likely a real failure'
          else
            system_test_jobs.each do |job_id, job_name|
              puts "  → gh run rerun --job #{job_id} (#{job_name})"
              system('gh', 'run', 'rerun', '--repo', repo, '--job', job_id)
            end
            store.record_run(pr_number.to_i, kind: 'retry')
            st[:system] = '⏳'
          end
          print_dashboard(st)
        end

        if has_codeql
          puts ''
          puts '  → 🔒 CodeQL findings — requires manual review on GitHub Security tab'
        end

        # Step 2: Specs fix (claude -p)
        if has_specs && failed_spec_files.any?
          puts ''
          puts '  failed specs:'
          failed_spec_files.each { |f| puts "    #{f}" }
          puts ''

          git_log, = Open3.capture2('git', 'log', 'main..HEAD', '--oneline', chdir: repo_path)

          claude_prompt = <<~PROMPT
            CI detected failing specs in this project.

            ## PR commits
            #{git_log.strip}

            ## Failed specs (from CI)
            #{failed_spec_files.join("\n")}

            ## Instructions
            1. Run the failing specs to see the actual errors
            2. Read the spec files and the implementation code
            3. Understand why each spec fails and fix the code (not the spec, unless the spec itself is wrong)
            4. Re-run the specs to verify your fix
            Do NOT commit. Do NOT push.
          PROMPT

          puts '  → claude fixing specs ...'
          claude_log = File.join(logdir, 'claude.log')
          puts "  → logs: #{claude_log}"

          claude_ok = system(
            'claude', '-p', claude_prompt,
            '--allowedTools', 'Read,Edit,Glob,Grep,Bash(bundle exec rspec:*),Bash(git diff:*),Bash(git status)',
            '--output-format', 'stream-json', '--verbose', '--max-turns', '20',
            chdir: repo_path,
            out: claude_log, err: claude_log
          )

          result[:output_path] = claude_log
          result[:turns_used] = Nightshift.count_turns(claude_log)

          diff_stat, = Open3.capture2('git', 'diff', '--stat', chdir: repo_path)
          if !claude_ok
            puts "  ⚠ claude exited with error (see #{claude_log})"
            st[:unit] = '🔴'
          elsif diff_stat.strip.empty?
            puts '  ⚠ claude made no changes'
            st[:unit] = '🔴'
          else
            st[:unit] = '🟡'
          end
          print_dashboard(st)
        end

        # Step 3: Linters
        if has_linter
          puts ''
          puts '  → fixing linters ...'

          rb_files, = Open3.capture2('git', 'diff', 'main', '--name-only', chdir: repo_path)
          rb_files = rb_files.lines.map(&:strip).select { |f| f.end_with?('.rb') }

          if rb_files.any?
            puts "  → rubocop -A (#{rb_files.size} files)"
            system('bundle', 'exec', 'rubocop', '-A', *rb_files, chdir: repo_path,
                                                                 out: File.join(logdir, 'rubocop.log'), err: File.join(logdir, 'rubocop.log'))
          end

          system('bun', 'lint:herb', '--fix', chdir: repo_path,
                                              out: File.join(logdir, 'herb.log'), err: File.join(logdir, 'herb.log'))
          system('bundle', 'exec', 'rake', 'lint:apostrophe:fix', chdir: repo_path,
                                                                  out: File.join(logdir, 'apostrophe.log'), err: File.join(logdir, 'apostrophe.log'))
          system('bundle', 'exec', 'rake', 'lint:yaml_newline:fix', chdir: repo_path,
                                                                    out: File.join(logdir, 'yaml.log'), err: File.join(logdir, 'yaml.log'))

          st[:linter] = '🟡'
          print_dashboard(st)
        end

        # Step 4: Verify
        puts ''
        puts '  → verifying ...'

        if has_linter
          rb_files, = Open3.capture2('git', 'diff', 'main', '--name-only', chdir: repo_path)
          rb_files = rb_files.lines.map(&:strip).select { |f| f.end_with?('.rb') }
          if rb_files.any?
            verify_log = File.join(logdir, 'verify-rubocop.log')
            system('bundle', 'exec', 'rubocop', *rb_files, chdir: repo_path,
                                                           out: verify_log, err: verify_log)
            summary = Monitoring::Diagnose.strip_ansi(File.readlines(verify_log).last&.strip || '')
            st[:linter] = if summary.include?('no offenses')
                            '🟢'
                          else
                            '🔴'
                          end
            puts "  rubocop: #{summary}"
          end
        end

        if has_specs && failed_spec_files.any?
          spec_paths = failed_spec_files.map { |f| f.sub(/^rspec /, '') }
          verify_log = File.join(logdir, 'verify-rspec.log')
          system('bundle', 'exec', 'rspec', *spec_paths, chdir: repo_path,
                                                         out: verify_log, err: verify_log)
          raw_summary = File.readlines(verify_log).grep(/\d+ examples?/).last&.strip || ''
          summary = Monitoring::Diagnose.strip_ansi(raw_summary)
          st[:unit] = if summary.include?('0 failures') && !summary.match?(/error.*occurred/)
                        '🟢'
                      else
                        '🔴'
                      end
          puts "  specs: #{summary}"
        end

        puts "  system tests: https://github.com/#{repo}/actions/runs/#{run_id}" if system_test_jobs.any?

        print_dashboard(st)

        # Show diff
        puts ''
        changed, = Open3.capture2('git', 'diff', '--name-only', chdir: repo_path)
        if changed.strip.empty?
          puts '  ✅ done (no local changes)'
          result[:files_changed] = 0
        else
          count = changed.lines.size
          result[:files_changed] = count
          puts "  #{count} file(s) modified:"
          puts ''
          system('git', 'diff', '--color', '--stat', chdir: repo_path)
          puts ''
          system('git', 'diff', '--color', chdir: repo_path)
          puts ''
          puts '  next: git add -u && git commit && git push mfo HEAD'
        end
      end

      def print_dashboard(st)
        puts ''
        puts "  #{st[:linter]} linter   #{st[:unit]} unit   #{st[:codeql]} codeql   #{st[:system]} system"
        puts '  ──────────────────────────────────────────────'
      end
    end
  end
end
