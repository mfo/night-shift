require "open3"
require "set"

module Nightshift
  module Worktree
    module_function

    # Returns Set of branch names from all worktrees
    def branches(repo_path = ENV.fetch("NIGHTSHIFT_REPO"))
      out, = Open3.capture2("git", "-C", repo_path, "worktree", "list")
      branches = Set.new
      out.each_line do |line|
        match = line.match(/\[(.+)\]/)
        branches << match[1] if match
      end
      branches
    end

    # Returns [[path, branch], ...] for all worktrees (excluding main)
    def list(repo_path = ENV.fetch("NIGHTSHIFT_REPO"))
      out, = Open3.capture2("git", "-C", repo_path, "worktree", "list")
      out.lines.drop(1).filter_map do |line|
        wt_path = line.split.first&.sub(/^~/, Dir.home)
        branch_match = line.match(/\[(.+)\]/)
        next unless branch_match && wt_path && File.directory?(wt_path)
        [wt_path, branch_match[1]]
      end
    end

    # Returns worktree path for a given branch, or nil
    def path_for_branch(branch, repo_path = ENV.fetch("NIGHTSHIFT_REPO"))
      out, = Open3.capture2("git", "-C", repo_path, "worktree", "list")
      out.each_line do |line|
        return line.split.first if line.include?("[#{branch}]")
      end
      nil
    end

    # Returns main worktree path
    def main_path(repo_path = ENV.fetch("NIGHTSHIFT_REPO"))
      out, = Open3.capture2("git", "-C", repo_path, "worktree", "list")
      path = out.lines.first&.split&.first
      path&.sub(/^~/, Dir.home) || repo_path
    end
  end
end
