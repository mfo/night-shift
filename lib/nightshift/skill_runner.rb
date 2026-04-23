require "open3"
require "shellwords"

module Nightshift
  module SkillRunner
    module_function

    def run(skill_name, item:, worktree_path:)
      prompt = "/#{skill_name} #{item}"

      logdir = File.join(worktree_path, "tmp")
      FileUtils.mkdir_p(logdir)
      log_path = File.join(logdir, "claude-#{skill_name}.log")

      puts "── SKILL #{skill_name} — #{item} ──────────────────────"

      claude_ok = run_with_tee(
        "claude", "-p", prompt,
        "--permission-mode", "acceptEdits",
        "--output-format", "stream-json",
        "--verbose", "--max-turns", "200",
        log_path: log_path, chdir: worktree_path
      )

      commits, = Open3.capture2("git", "log", "main..HEAD", "--oneline",
                                chdir: worktree_path)
      has_commits = !commits.strip.empty?

      {
        success: claude_ok && has_commits,
        failure_reason: failure_reason(claude_ok, has_commits),
        log_path: log_path,
        turns_used: Nightshift.count_turns(log_path),
        files_changed: has_commits ? commits.lines.size : 0
      }
    end

    def run_with_tee(*cmd, log_path:, chdir:)
      tee_pipe = IO.popen(["tee", log_path], "w")
      pid = spawn(*cmd, out: tee_pipe, err: tee_pipe, chdir: chdir)
      _, status = Process.waitpid2(pid)
      tee_pipe.close
      status.success?
    end

    KAIZEN_CATEGORIES = {
      "haml-migration" => "1-haml",
      "test-optimization" => "2-test-optimization",
      "harden-audit" => "5-harden",
      "harden-pentest" => "5-harden"
    }.freeze

    def analyze_failure(skill_name, item:, worktree_path:, failure_reason:)
      log_path = File.join(worktree_path, "tmp", "claude-#{skill_name}.log")
      return unless File.exist?(log_path)

      kaizen_local = File.join(worktree_path, "tmp", "kaizen.md")
      category = KAIZEN_CATEGORIES[skill_name] || "6-nightshift"
      slug = File.basename(item, File.extname(item)).gsub(/[^a-z0-9]+/i, "-").downcase
      today = Time.now.strftime("%Y-%m-%d")
      kaizen_nightshift = File.expand_path("~/dev/night-shift/kaizen/#{category}/#{today}-#{slug}-failed.md")

      prompt = <<~PROMPT
        Le skill "#{skill_name}" a echoue en mode auto sur "#{item}" (reason: #{failure_reason}).

        1. Lis le log #{log_path} (format stream-json)
        2. Identifie les problemes : permissions denied, fichiers introuvables, boucles/retries, cause racine
        3. Ecris un kaizen dans DEUX fichiers :
           - #{kaizen_local}
           - #{kaizen_nightshift}

        Utilise le format kaizen standard (Ce qui s'est passe, bien passe, mal passe, appris, permissions bloquantes, actions).
        Sois concis et actionnable.
      PROMPT

      puts "── KAIZEN #{skill_name} — analyzing failure ──────────────"
      system(
        "claude", "-p", prompt,
        "--permission-mode", "acceptEdits",
        "--output-format", "stream-json",
        "--verbose", "--max-turns", "15",
        chdir: worktree_path
      )
    end

    def failure_reason(claude_ok, has_commits)
      return nil if claude_ok && has_commits
      return "claude_error" unless claude_ok
      "no_diff"
    end
  end
end
