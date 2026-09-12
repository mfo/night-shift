# frozen_string_literal: true

require 'open3'

module Nightshift
  module Integrations
    #
    # Worktree — Git worktree management
    #
    # Lists, creates, and removes git worktrees. Each worktree is an
    # isolated branch checkout used by a skill or a manual PR.
    # Cleanup includes removing the worktree dir, branch, and test databases
    # (the worktree's own plus its parallel_tests sisters).
    #
    module Worktree
      extend T::Sig
      module_function

      # Union sur tous les repos declares. Sans elle, `health_check` ne voit
      # pas les branches vivant hors du repo hote et les classe zombie a chaque
      # tick — l'item repasse en Pending pendant que son run est en vol.
      sig { returns(T::Set[String]) }
      def all_branches
        Nightshift.repos.each_value.reduce(Set.new) do |acc, repo|
          acc | branches(repo.path)
        end
      end

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

      sig { params(branch: String, repo_path: T.nilable(String)).returns(T.nilable(String)) }
      def path_for_branch(branch, repo_path = nil)
        repo_path ||= Nightshift.repo_path_for_branch(branch)
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

      # Test databases are named tps_test_<worktree suffix> (post-checkout), and
      # bin/parallel-rspec adds one sister per extra process — tps_test_foo2 …
      # tps_test_foo8, from database.yml appending TEST_ENV_NUMBER.
      DB_PREFIX = 'tps_test'
      DB_USER = 'tps_test'
      DB_HOST = 'localhost'

      sig { params(wt_path: String).returns(String) }
      def db_name_for(wt_path)
        db_suffix = File.basename(wt_path).sub(/^demarches-simplifiees\.fr-/, '').gsub('-', '_')
        "#{DB_PREFIX}_#{db_suffix}"
      end

      # The database itself and its parallel sisters — and nothing else. A naive
      # LIKE 'tps_test_foo%' would also match tps_test_foobar, i.e. another
      # worktree's database; anchoring on nought to two trailing digits keeps
      # the blast radius to the family we own.
      sig { params(db_name: String).returns(Regexp) }
      def db_family(db_name) = /\A#{Regexp.escape(db_name)}\d{0,2}\z/

      sig { returns(T::Array[String]) }
      def all_databases
        out, status = Open3.capture2(
          'psql', '-U', DB_USER, '-h', DB_HOST, '-d', 'postgres', '-tAc',
          'SELECT datname FROM pg_database'
        )
        return [] unless status.success?

        out.lines.map(&:strip).reject(&:empty?)
      end

      # Families that must never be dropped: the main working tree (plain
      # tps_test / tps_test2 …, straight from .env.test) and every live
      # worktree. `except` opts the worktree being torn down back out.
      sig { params(repo_path: String, except: T.nilable(String)).returns(T::Array[Regexp]) }
      def reserved_db_families(repo_path = Nightshift.repo_path, except: nil)
        families = [db_family(DB_PREFIX)]
        list(repo_path).each do |wt_path, _branch|
          next if except && File.expand_path(wt_path) == File.expand_path(except)

          families << db_family(db_name_for(wt_path))
        end
        families
      end

      # Databases matching no live worktree — left behind by worktrees removed
      # by hand, or created before cleanup learned to drop the sisters. Only
      # the tps_test_<suffix> namespace is considered: the main working tree's
      # own family is reserved, and tps_development / tps_tests are none of
      # our business.
      sig { params(repo_path: String).returns(T::Array[String]) }
      def orphan_databases(repo_path = Nightshift.repo_path)
        reserved = reserved_db_families(repo_path)
        all_databases
          .select { |db| db.start_with?("#{DB_PREFIX}_") }
          .reject { |db| reserved.any? { |family| family.match?(db) } }
          .sort
      end

      sig { params(wt_path: String, repo_path: String).returns(T::Array[String]) }
      def databases_for(wt_path, repo_path = Nightshift.repo_path)
        db_name = db_name_for(wt_path)
        family = db_family(db_name)
        # A suffix ending in digits can collide: worktree `1340` claims
        # tps_test_13403, which belongs to worktree `13403`. Reserved families
        # win. The exact name can only ever be ours, so it is never filtered.
        reserved = reserved_db_families(repo_path, except: wt_path)

        sisters = all_databases
                  .select { |db| family.match?(db) && db != db_name }
                  .reject { |db| reserved.any? { |other| other.match?(db) } }

        [db_name] + sisters.sort
      end

      sig { params(names: T::Array[String]).void }
      def drop_databases(names)
        names.each do |db|
          system('dropdb', '-U', DB_USER, '-h', DB_HOST, '--if-exists', db)
        end
      end

      sig { params(branch: String, repo_path: T.nilable(String)).void }
      def cleanup(branch, repo_path = nil)
        repo_path ||= Nightshift.repo_path_for_branch(branch)
        wt_path = path_for_branch(branch, repo_path)
        main = main_path(repo_path)

        # Never touch the main working tree
        if wt_path && File.expand_path(wt_path) == File.expand_path(main)
          Log.warn "cleanup refused: #{branch} points to main working tree #{main}"
          return
        end

        # Drop test databases: the worktree's own, plus the parallel_tests
        # sisters bin/parallel-rspec creates (mirrors post-checkout naming)
        if wt_path
          drop_databases(databases_for(wt_path, repo_path))
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
