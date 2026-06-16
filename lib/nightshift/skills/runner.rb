# frozen_string_literal: true
# typed: false

require 'json'
require 'open3'
require 'shellwords'
require 'yaml'

module Nightshift
  module Skills
    #
    # Runner — Claude Code invocation in a worktree
    #
    # Loads the skill prompt via Loader, writes optional context,
    # invokes `claude -p` with scoped allowed tools, streams output
    # to a log file, and returns a RunnerResult.
    #
    module Runner
      extend T::Sig

      module_function

      sig do
        params(
          skill_name: String,
          item: String,
          worktree_path: String,
          context: T.nilable(String)
        ).returns(RunnerResult)
      end
      def run(skill_name, item:, worktree_path:, context: nil)
        prompt = "/#{skill_name} #{item}"

        # Write context file if provided (consumed by the skill prompt)
        if context
          ctx_path = File.join(worktree_path, '.skill-context.json')
          File.write(ctx_path, context)
        end

        logdir = File.join(worktree_path, 'tmp')
        FileUtils.mkdir_p(logdir)
        log_path = File.join(logdir, "claude-#{skill_name}.log")

        Log.info "── SKILL #{skill_name} — #{item} ──────────────────────"

        # Snapshot commit count before run (for batch: detect NEW commits only)
        commits_before, = Open3.capture2('git', 'rev-list', '--count', 'main..HEAD',
                                         chdir: worktree_path)
        commits_before = commits_before.strip.to_i

        allowed = extract_allowed_tools(skill_name, worktree_path)
        binary = Nightshift.runner_for(skill_name)
        cmd = [binary, '-p', prompt,
               '--permission-mode', 'acceptEdits',
               '--output-format', 'stream-json',
               '--verbose', '--max-turns', '200']
        cmd += ['--allowedTools', *allowed] if allowed.any?

        claude_ok = run_with_tee(*cmd, log_path: log_path, chdir: worktree_path)
        rate_limited = !claude_ok && detect_rate_limit(log_path)

        commits_after, = Open3.capture2('git', 'rev-list', '--count', 'main..HEAD',
                                        chdir: worktree_path)
        commits_after = commits_after.strip.to_i
        new_commits = commits_after - commits_before

        RunnerResult.new(
          success: claude_ok && new_commits.positive?,
          failure_reason: rate_limited ? FailureReason::RateLimited.serialize : failure_reason(claude_ok, new_commits.positive?),
          log_path: log_path,
          turns_used: Nightshift.count_turns(log_path),
          files_changed: new_commits
        )
      end

      sig { params(skill_name: String, worktree_path: String).returns(T::Array[String]) }
      def extract_allowed_tools(skill_name, worktree_path)
        skill_md = File.join(worktree_path, '.claude', 'skills', skill_name, 'SKILL.md')
        return [] unless File.exist?(skill_md)

        content = File.read(skill_md)
        # Extract YAML frontmatter
        match = content.match(/\A---\s*\n(.*?\n)---/m)
        return [] unless match

        frontmatter = YAML.safe_load(match[1], permitted_classes: [Symbol]) || {}
        tools = Array(frontmatter['allowed-tools'])
        # YAML may return a single comma-separated string — split into individual tools
        tools.flat_map { |t| t.include?(',') ? t.split(/,\s*/) : t }
      rescue StandardError
        []
      end

      def run_with_tee(*cmd, log_path:, chdir:)
        tee_pipe = IO.popen(['tee', log_path], 'w')
        pid = spawn(*cmd, out: tee_pipe, err: tee_pipe, chdir: chdir)
        _, status = Process.waitpid2(pid)
        tee_pipe.close
        status.success?
      end

      KAIZEN_CATEGORIES = {
        'haml-migration' => '1-haml',
        'test-optimization' => '2-test-optimization',
        'harden-audit' => '5-harden',
        'harden-pentest' => '5-harden',
        'bugfix' => '3-bugs',
        'n1-query-fix' => '4-n1',
        'i18n-hardcoded' => '7-i18n'
      }.freeze

      def analyze_run(skill_name, item:, log_path:, outcome:, failure_reason: nil)
        return unless File.exist?(log_path)

        category = KAIZEN_CATEGORIES[skill_name] || '6-nightshift'
        slug = File.basename(item, File.extname(item)).gsub(/[^a-z0-9]+/i, '-').downcase
        today = Time.now.strftime('%Y-%m-%d')
        suffix = outcome == :success ? 'ok' : 'failed'
        kaizen_path = File.expand_path("~/dev/night-shift/kaizen/#{category}/#{today}-#{slug}-#{suffix}.md")

        persistent_log_dir = File.expand_path('~/dev/night-shift/tmp/logs')
        FileUtils.mkdir_p(persistent_log_dir)
        persistent_log = File.join(persistent_log_dir, "#{today}-#{skill_name}-#{slug}.log")
        FileUtils.cp(log_path, persistent_log)

        prompt = if outcome == :success
                   <<~PROMPT
                     Le skill "#{skill_name}" a reussi en mode auto sur "#{item}".

                     1. Lis le log #{persistent_log} (format stream-json)
                     2. Identifie : strategies efficaces, tours economises, patterns reutilisables, points d'amelioration
                     3. Ecris un kaizen dans #{kaizen_path}

                     Utilise le format kaizen standard (Ce qui s'est passe, bien passe, mal passe, appris, permissions bloquantes, actions).
                     Score > 5 = succes. Sois concis et actionnable.
                   PROMPT
                 else
                   <<~PROMPT
                     Le skill "#{skill_name}" a echoue en mode auto sur "#{item}" (reason: #{failure_reason}).

                     1. Lis le log #{persistent_log} (format stream-json)
                     2. Identifie les problemes : permissions denied, fichiers introuvables, boucles/retries, cause racine
                     3. Ecris un kaizen dans #{kaizen_path}

                     Utilise le format kaizen standard (Ce qui s'est passe, bien passe, mal passe, appris, permissions bloquantes, actions).
                     Sois concis et actionnable.
                   PROMPT
                 end

        Log.info "── KAIZEN #{skill_name} — analyzing #{outcome} ──────────────"
        nightshift_dir = File.expand_path('~/dev/night-shift')
        binary = Nightshift.runner
        pid = Process.spawn(
          binary, '-p', prompt,
          '--permission-mode', 'acceptEdits',
          '--output-format', 'text',
          '--max-turns', '15',
          chdir: nightshift_dir,
          out: File::NULL, err: File::NULL
        )
        Process.detach(pid)
        Log.info "kaizen analysis spawned (pid: #{pid})"
        pid
      end

      def detect_rate_limit(log_path)
        return false unless File.exist?(log_path)

        File.foreach(log_path) do |line|
          event = begin
            JSON.parse(line.strip)
          rescue StandardError
            next
          end
          return true if event['type'] == 'rate_limit_event'
        end
        false
      rescue StandardError
        false
      end

      def failure_reason(claude_ok, has_commits)
        return nil if claude_ok && has_commits
        return FailureReason::ClaudeError.serialize unless claude_ok

        FailureReason::NoDiff.serialize
      end
    end
  end
end
