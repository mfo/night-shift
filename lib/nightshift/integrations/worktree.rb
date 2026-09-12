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

      # Provisionne le `.claude/` d'un worktree frais : skills et agents, rien
      # d'autre.
      #
      # Le hook `post-checkout` faisait ce travail *et* celui d'installer
      # l'environnement du repo (bases de test, bundle, bun, lefthook). Les
      # deux mecanismes se recouvraient sur `.claude/`, avec des contrats
      # differents — le hook ne copie que si le repertoire est absent et saute
      # `settings.json`, cette fonction copiait tout inconditionnellement. Le
      # hook s'executant pendant `git worktree add`, donc avant, rendre cette
      # fonction vivante aurait ecrase les permissions a chaque worktree.
      #
      # Le partage se fait desormais par nature : ici le provisioning Claude,
      # pour tous les repos ; au hook l'environnement, propre a chacun.
      sig { params(wt_path: String, repo: T.nilable(Core::Repo)).void }
      def setup(wt_path, repo = nil)
        source = File.join(File.expand_path('../../..', __dir__), '.claude')
        return unless Dir.exist?(source)

        target = File.join(wt_path, '.claude')
        FileUtils.mkdir_p(target)

        copy_claude_entry(source, target, 'skills', repo&.worktree_skills)
        copy_claude_entry(source, target, 'agents', repo&.worktree_agents)

        # Versionne dans les repos cibles : l'ecraser supprimerait leurs regles
        # de permissions. Les reglages partages passent par settings.local.json.
        Dir.children(source).each do |name|
          next if %w[skills agents settings.json].include?(name)

          FileUtils.cp_r(File.join(source, name), File.join(target, name))
        end

        Log.info "worktree claude: #{File.basename(wt_path)}"
      end

      # `nil` embarque tout le repertoire ; une liste n'en prend que les
      # entrees nommees. Une entree demandee mais absente est signalee plutot
      # que passee sous silence : c'est ainsi qu'un `/skill` finit en *Unknown
      # command* dans un worktree, apres quoi le run part en no_diff.
      sig { params(source: String, target: String, kind: String, wanted: T.nilable(T::Array[String])).void }
      def copy_claude_entry(source, target, kind, wanted)
        src_dir = File.join(source, kind)
        return unless Dir.exist?(src_dir)

        if wanted.nil?
          FileUtils.cp_r(src_dir, File.join(target, kind))
          return
        end

        dest_dir = File.join(target, kind)
        FileUtils.mkdir_p(dest_dir)
        wanted.each do |name|
          entry = Dir[File.join(src_dir, name), File.join(src_dir, "#{name}.md")].first
          if entry.nil?
            Log.warn "worktree claude: #{kind}/#{name} introuvable dans night-shift"
            next
          end
          FileUtils.cp_r(entry, dest_dir)
        end
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
