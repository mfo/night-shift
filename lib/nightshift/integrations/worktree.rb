# frozen_string_literal: true

require 'open3'

module Nightshift
  module Integrations
    #
    # Worktree — Git worktree management
    #
    # Lists, creates, and removes git worktrees. Each worktree is an
    # isolated branch checkout used by a skill or a manual PR.
    # Cleanup includes removing the worktree dir, branch, and test DB.
    #
    module Worktree
      extend T::Sig
      module_function

      sig { params(repo_path: String).returns(T::Set[String]) }
      def branches(repo_path = Nightshift.repo_path)
        out, = Open3.capture2('git', '-C', repo_path, 'worktree', 'list')
        branches = Set.new
        out.each_line do |line|
          match = line.match(/\[(.+)\]/)
          branches << match[1] if match
        end
        branches
      end

      sig { params(repo_path: String).returns(T::Array[[String, String]]) }
      def list(repo_path = Nightshift.repo_path)
        out, = Open3.capture2('git', '-C', repo_path, 'worktree', 'list')
        out.lines.drop(1).filter_map do |line|
          wt_path = line.split.first&.sub(/^~/, Dir.home)
          branch_match = line.match(/\[(.+)\]/)
          next unless branch_match && wt_path && File.directory?(wt_path)

          [wt_path, branch_match[1]]
        end
      end

      sig { params(branch: String, repo_path: String).returns(T.nilable(String)) }
      def path_for_branch(branch, repo_path = Nightshift.repo_path)
        out, = Open3.capture2('git', '-C', repo_path, 'worktree', 'list')
        out.each_line do |line|
          return line.split.first if line.include?("[#{branch}]")
        end
        nil
      end

      sig { params(repo_path: String).returns(String) }
      def main_path(repo_path = Nightshift.repo_path)
        out, = Open3.capture2('git', '-C', repo_path, 'worktree', 'list')
        path = out.lines.first&.split&.first
        path&.sub(/^~/, Dir.home) || repo_path
      end

      sig { params(wt_path: String, repo_path: String).void }
      def setup(wt_path, repo_path = Nightshift.repo_path)
        # Lefthook config (not committed, must be copied)
        %w[lefthook.yml].each do |f|
          src = File.join(repo_path, f)
          FileUtils.cp(src, wt_path) if File.exist?(src)
        end
        lefthook_dir = File.join(repo_path, '.lefthook')
        if Dir.exist?(lefthook_dir)
          FileUtils.cp_r(lefthook_dir, File.join(wt_path, '.lefthook'))
        end

        # .claude/ from night-shift (skills, settings — sans agents)
        nightshift_dir = File.expand_path('../../..', __dir__)
        nightshift_claude = File.join(nightshift_dir, '.claude')
        if Dir.exist?(nightshift_claude)
          claude_target = File.join(wt_path, '.claude')
          FileUtils.mkdir_p(claude_target)
          Dir.children(nightshift_claude).each do |name|
            next if name == 'agents'
            FileUtils.cp_r(File.join(nightshift_claude, name), File.join(claude_target, name))
          end
        end

        # Install lefthook in worktree
        system('lefthook', 'install', chdir: wt_path, out: File::NULL, err: File::NULL)

        Log.info "worktree setup: #{File.basename(wt_path)}"
      end

      sig { params(branch: String, repo_path: String).void }
      def cleanup(branch, repo_path: Nightshift.repo_path)
        wt_path = path_for_branch(branch, repo_path)
        main = main_path(repo_path)

        # Never touch the main working tree
        if wt_path && File.expand_path(wt_path) == File.expand_path(main)
          Log.warn "cleanup refused: #{branch} points to main working tree #{main}"
          return
        end

        # Drop test database (mirrors post-checkout naming convention)
        if wt_path
          wt_name = File.basename(wt_path)
          db_suffix = wt_name.sub(/^demarches-simplifiees\.fr-/, '').gsub('-', '_')
          db_name = "tps_test_#{db_suffix}"
          system('dropdb', '-U', 'tps_test', '-h', 'localhost', '--if-exists', db_name)
        end

        # Remove worktree (or orphan directory if git doesn't track it)
        if wt_path
          system('git', '-C', repo_path, 'worktree', 'remove', wt_path, '--force')
          FileUtils.rm_rf(wt_path) if Dir.exist?(wt_path)
        end

        # Delete branch
        system('git', '-C', repo_path, 'branch', '-D', branch, err: File::NULL)
      end
    end
  end
end
