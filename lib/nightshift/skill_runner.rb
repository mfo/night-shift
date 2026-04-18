require "open3"

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

      claude_ok = system(
        "claude", "-p", prompt,
        "--allowedTools", skill[:allowed_tools],
        "--output-format", "stream-json",
        "--verbose", "--max-turns", "30",
        chdir: worktree_path,
        out: log_path, err: log_path
      )

      commits, = Open3.capture2("git", "log", "main..HEAD", "--oneline",
                                chdir: worktree_path)
      has_commits = !commits.strip.empty?

      {
        success: claude_ok && has_commits,
        failure_reason: failure_reason(claude_ok, has_commits),
        log_path: log_path,
        turns_used: count_turns(log_path),
        files_changed: has_commits ? commits.lines.size : 0
      }
    end

    def build_prompt(skill, item)
      skill[:prompt].gsub("$ARGUMENTS", item)
    end

    def count_turns(log_path)
      return nil unless File.exist?(log_path)
      File.read(log_path).scan(/"type"\s*:\s*"assistant"/).size
    rescue
      nil
    end

    def failure_reason(claude_ok, has_commits)
      return nil if claude_ok && has_commits
      return "claude_error" unless claude_ok
      "no_diff"
    end
  end
end
