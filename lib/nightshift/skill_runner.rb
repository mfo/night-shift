require "open3"
require "shellwords"

module Nightshift
  module SkillRunner
    module_function

    def run(skill_name, item:, worktree_path:)
      skill = SkillLoader.load(skill_name)
      prompt = build_prompt(skill, item)

      logdir = File.join(worktree_path, "tmp")
      FileUtils.mkdir_p(logdir)
      log_path = File.join(logdir, "claude-#{skill_name}.log")

      puts "── SKILL #{skill_name} — #{item} ──────────────────────"

      claude_ok = run_with_tee(
        "claude", "-p", prompt,
        "--allowedTools", skill[:allowed_tools],
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

    def build_prompt(skill, item)
      port = ENV.fetch("NIGHTSHIFT_PORT", "3000")
      skill[:prompt]
        .gsub("$ARGUMENTS", item)
        .gsub("$PORT", port)
    end

    def run_with_tee(*cmd, log_path:, chdir:)
      tee_pipe = IO.popen(["tee", log_path], "w")
      pid = spawn(*cmd, out: tee_pipe, err: tee_pipe, chdir: chdir)
      _, status = Process.waitpid2(pid)
      tee_pipe.close
      status.success?
    end

    def failure_reason(claude_ok, has_commits)
      return nil if claude_ok && has_commits
      return "claude_error" unless claude_ok
      "no_diff"
    end
  end
end
