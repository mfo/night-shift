# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'minitest/mock'

#
# dirty? and unpushed? are the two predicates standing between the doctor and a
# loss of work that exists as no git object anywhere. They run against a real
# repository here, because a stubbed git proves nothing about them.
#
class GitHygieneTest < Minitest::Test
  GIT = Nightshift::Integrations::Git

  def setup
    @root = Dir.mktmpdir('nightshift-git')
    @repo = File.join(@root, 'repo')
    FileUtils.mkdir_p(@repo)
    git!('init', '-b', 'main')
    git!('config', 'user.email', 'test@example.com')
    git!('config', 'user.name', 'test')
    File.write(File.join(@repo, 'README'), "hello\n")
    git!('add', '.')
    git!('commit', '-m', 'init', '--no-gpg-sign')
  end

  def teardown
    FileUtils.remove_entry(@root) if @root && Dir.exist?(@root)
  end

  # NB: not `run` — that is Minitest::Runnable's own entry point.
  def git!(*args, dir: @repo)
    _, err, status = Open3.capture3('git', '-C', dir, *args)
    raise "git #{args.join(' ')} failed: #{err}" unless status.success?
  end

  def test_dirty_is_false_on_a_clean_tree
    refute GIT.dirty?(@repo)
  end

  def test_dirty_is_true_when_a_tracked_file_changed
    File.write(File.join(@repo, 'README'), "changed\n")

    assert GIT.dirty?(@repo)
  end

  def test_untracked_files_alone_do_not_count_as_dirty
    # A worktree is full of build artefacts. Those are not work.
    File.write(File.join(@repo, 'tmp.log'), "noise\n")

    refute GIT.dirty?(@repo)
  end

  def test_dirty_returns_nil_outside_a_repository
    assert_nil GIT.dirty?(@root), 'unknown must not be reported as clean'
  end

  def test_unpushed_is_false_when_the_branch_matches_its_base
    refute GIT.unpushed?(@repo, base: 'main')
  end

  def test_unpushed_is_true_for_a_commit_that_exists_only_here
    git!('checkout', '-b', 'feature')
    File.write(File.join(@repo, 'new.txt'), "work\n")
    git!('add', '.')
    git!('commit', '-m', 'local work', '--no-gpg-sign')

    assert GIT.unpushed?(@repo, base: 'main')
  end

  def test_unpushed_returns_nil_when_no_base_can_be_resolved
    assert_nil GIT.unpushed?(@repo, base: 'does-not-exist')
  end

  def test_merged_branches_excludes_the_base_itself
    git!('checkout', '-b', 'merged-already')
    git!('checkout', 'main')

    branches = GIT.merged_branches(@repo, base: 'main')
    assert_includes branches, 'merged-already'
    refute_includes branches, 'main'
  end

  def test_merged_branches_skips_a_branch_with_its_own_commits
    git!('checkout', '-b', 'ahead')
    File.write(File.join(@repo, 'new.txt'), "work\n")
    git!('add', '.')
    git!('commit', '-m', 'ahead', '--no-gpg-sign')
    git!('checkout', 'main')

    refute_includes GIT.merged_branches(@repo, base: 'main'), 'ahead'
  end

  def test_delete_branch_refuses_an_unmerged_branch
    git!('checkout', '-b', 'ahead')
    File.write(File.join(@repo, 'new.txt'), "work\n")
    git!('add', '.')
    git!('commit', '-m', 'ahead', '--no-gpg-sign')
    git!('checkout', 'main')

    refute GIT.delete_branch(@repo, 'ahead'), 'git -d must refuse to drop unmerged commits'
    assert_includes GIT.merged_branches(@repo, base: 'ahead'), 'main'
  end

  def test_default_base_prefers_main
    assert_equal 'main', GIT.default_base(@repo)
  end
end

#
# Ghost directories are found by walking the filesystem, because git by
# definition no longer knows about them.
#
class GhostDirTest < Minitest::Test
  WT = Nightshift::Integrations::Worktree

  def setup
    @root = Dir.mktmpdir('nightshift-ghosts')
    @repo = File.join(@root, 'repo')
    FileUtils.mkdir_p(File.join(@repo, '.git', 'worktrees'))
  end

  def teardown
    FileUtils.remove_entry(@root) if @root && Dir.exist?(@root)
  end

  def make(name, git: nil)
    path = File.join(@root, name)
    FileUtils.mkdir_p(path)
    File.write(File.join(path, '.git'), "gitdir: #{git}\n") if git
    path
  end

  def ghosts(known: [])
    WT.stub(:entries, known.map { |p| Nightshift::Core::WorktreeEntry.new(path: p) }) do
      WT.ghost_dirs(@repo, roots: [@root])
    end
  end

  def test_a_dangling_git_file_is_a_ghost
    make('degraded', git: File.join(@repo, '.git', 'worktrees', 'degraded'))

    found = ghosts.find { |g| g[:path].end_with?('degraded') }
    assert_equal :dangling_git, found[:kind]
    refute found[:verifiable], 'the admin entry is gone, git cannot be asked anything'
  end

  def test_a_live_admin_entry_is_still_a_ghost_but_verifiable
    FileUtils.mkdir_p(File.join(@repo, '.git', 'worktrees', 'alive'))
    make('alive', git: File.join(@repo, '.git', 'worktrees', 'alive'))

    found = ghosts.find { |g| g[:path].end_with?('alive') }
    assert found[:verifiable]
  end

  def test_an_auto_directory_without_git_is_a_husk
    make('auto-i18n-hardcoded-batch-11d93b2e')

    found = ghosts.find { |g| g[:path].end_with?('11d93b2e') }
    assert_equal :auto_husk, found[:kind]
  end

  def test_a_registered_worktree_is_not_a_ghost
    path = make('registered', git: File.join(@repo, '.git', 'worktrees', 'registered'))

    assert_empty ghosts(known: [path]).select { |g| g[:path] == path }
  end

  def test_an_unrelated_directory_is_left_alone
    make('some-other-project')
    make('vendored', git: '/somewhere/else/.git')

    names = ghosts.map { |g| File.basename(g[:path]) }
    refute_includes names, 'some-other-project'
    refute_includes names, 'vendored'
  end
end
