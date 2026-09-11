# frozen_string_literal: true
# typed: true

require 'open3'

module Nightshift
  module Integrations
    #
    # Git — the read-only questions the inventory needs to ask, plus the two
    # reclaim primitives git itself makes safe (`prune`, `branch -d`).
    #
    # Every predicate returns nil when git could not answer. nil is not false:
    # callers must treat it as "unknown" and refuse to destroy anything.
    #
    module Git
      extend T::Sig
      module_function

      # Uncommitted changes, tracked files only. Untracked files are ignored on
      # purpose: a worktree is full of build artefacts and they are not work.
      sig { params(path: String).returns(T.nilable(T::Boolean)) }
      def dirty?(path)
        out, _, status = Open3.capture3('git', '-C', path, 'status', '--porcelain',
                                        '--untracked-files=no')
        return nil unless status.success?

        !out.strip.empty?
      end

      # Commits that exist only here. A branch with no upstream counts as
      # unpushed as soon as it has commits the base branch does not have.
      sig { params(path: String, base: String).returns(T.nilable(T::Boolean)) }
      def unpushed?(path, base: 'main')
        upstream, _, ok = Open3.capture3('git', '-C', path, 'rev-parse', '--abbrev-ref',
                                         '--symbolic-full-name', '@{upstream}')
        ref = ok.success? ? upstream.strip : nil

        unless ref
          ref = remote_base(path, base)
          return nil unless ref
        end

        out, _, status = Open3.capture3('git', '-C', path, 'rev-list', '--count', "#{ref}..HEAD")
        return nil unless status.success?

        out.strip.to_i.positive?
      end

      sig { params(path: String, base: String).returns(T.nilable(String)) }
      def remote_base(path, base)
        %W[origin/#{base} #{base}].find do |candidate|
          _, _, status = Open3.capture3('git', '-C', path, 'rev-parse', '--verify', '--quiet', candidate)
          status.success?
        end
      end

      sig { params(path: String).returns(Integer) }
      def dir_size(path)
        return 0 unless Dir.exist?(path)

        out, _, status = Open3.capture3('du', '-sk', path)
        return 0 unless status.success?

        (out.split.first.to_i) * 1024
      end

      # Local branches already contained in base. `--merged` is the whole point:
      # a branch it lists can be deleted with `-d`, which refuses anything else.
      sig { params(repo_path: String, base: String).returns(T::Array[String]) }
      def merged_branches(repo_path, base: 'main')
        out, _, status = Open3.capture3('git', '-C', repo_path, 'branch', '--merged', base,
                                        '--format=%(refname:short)')
        return [] unless status.success?

        out.lines.map(&:strip).reject { |b| b.empty? || b == base || b.start_with?('(') }
      end

      sig { params(repo_path: String).returns(T::Boolean) }
      def prune_worktrees(repo_path)
        system('git', '-C', repo_path, 'worktree', 'prune', out: File::NULL, err: File::NULL)
      end

      # Never -D. `-d` refuses to delete an unmerged branch, and that refusal is
      # the guard rail, not an inconvenience to work around.
      sig { params(repo_path: String, branch: String).returns(T::Boolean) }
      def delete_branch(repo_path, branch)
        system('git', '-C', repo_path, 'branch', '-d', branch, out: File::NULL, err: File::NULL)
      end

      sig { params(repo_path: String).returns(String) }
      def default_base(repo_path)
        %w[main master].find do |candidate|
          _, _, status = Open3.capture3('git', '-C', repo_path, 'rev-parse', '--verify',
                                        '--quiet', candidate)
          status.success?
        end || 'main'
      end
    end
  end
end
