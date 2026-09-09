# frozen_string_literal: true

require_relative 'test_helper'
require 'minitest/mock'

#
# Naming of the per-worktree test databases, and the blast radius of the drop
# performed at cleanup. The stakes: tps_test_foo and tps_test_foobar belong to
# two different worktrees, so the family pattern must never confuse them.
#
class WorktreeDbTest < Minitest::Test
  WT = Nightshift::Integrations::Worktree

  def test_db_name_strips_repo_prefix_and_dashes
    assert_equal 'tps_test_poc_haml', WT.db_name_for('/dev/demarches-simplifiees.fr-poc-haml')
    assert_equal 'tps_test_auto_i18n_x', WT.db_name_for('/dev/auto-i18n-x')
  end

  def test_db_family_matches_only_the_database_and_its_numbered_sisters
    family = WT.db_family('tps_test_foo')

    %w[tps_test_foo tps_test_foo2 tps_test_foo8 tps_test_foo42].each do |db|
      assert family.match?(db), "#{db} should belong to the family"
    end

    %w[tps_test_foobar tps_test_foo_bar tps_test_foo123 tps_test_fo tps_test xtps_test_foo].each do |db|
      refute family.match?(db), "#{db} must NOT belong to the family"
    end
  end

  def test_databases_for_returns_the_family_and_spares_look_alikes
    dbs = %w[
      tps_test tps_test2
      tps_test_foo tps_test_foo2 tps_test_foo3 tps_test_foo8
      tps_test_foobar tps_test_foobar2 tps_test_foo_bar
    ]

    names = with_stubs(dbs, [['/dev/demarches-simplifiees.fr-foo', 'foo']]) do
      WT.databases_for('/dev/demarches-simplifiees.fr-foo')
    end

    assert_equal %w[tps_test_foo tps_test_foo2 tps_test_foo3 tps_test_foo8], names
  end

  def test_databases_for_skips_a_sister_claimed_by_another_worktree
    # Worktree `1340` and worktree `13403` overlap: tps_test_13403 is a legit
    # sister name for the former but the main database of the latter.
    dbs = %w[tps_test_1340 tps_test_13402 tps_test_13403]
    worktrees = [
      ['/dev/demarches-simplifiees.fr-1340', 'w1'],
      ['/dev/demarches-simplifiees.fr-13403', 'w2']
    ]

    names = with_stubs(dbs, worktrees) do
      WT.databases_for('/dev/demarches-simplifiees.fr-1340')
    end

    assert_equal %w[tps_test_1340 tps_test_13402], names
  end

  def test_databases_for_always_includes_the_exact_name_even_when_absent
    names = with_stubs([], []) { WT.databases_for('/dev/demarches-simplifiees.fr-gone') }

    assert_equal ['tps_test_gone'], names
  end

  def test_orphan_databases_spares_main_and_live_worktrees
    dbs = %w[
      tps_test tps_test2 tps_test8
      tps_test_alive tps_test_alive2
      tps_test_dead tps_test_dead3
      tps_development tps_tests
    ]

    orphans = with_stubs(dbs, [['/dev/demarches-simplifiees.fr-alive', 'alive']]) do
      WT.orphan_databases
    end

    assert_equal %w[tps_test_dead tps_test_dead3], orphans
  end

  def test_cleanup_drops_the_whole_family
    dropped = nil
    dbs = %w[tps_test_gone tps_test_gone2 tps_test_gone_extra]

    with_stubs(dbs, [['/dev/demarches-simplifiees.fr-gone', 'gone']]) do
      WT.stub(:path_for_branch, '/dev/demarches-simplifiees.fr-gone') do
        WT.stub(:main_path, '/dev/demarches-simplifiees.fr') do
          WT.stub(:system, true) do
            WT.stub(:drop_databases, ->(names) { dropped = names }) do
              WT.cleanup('gone')
            end
          end
        end
      end
    end

    assert_equal %w[tps_test_gone tps_test_gone2], dropped
  end

  def test_cleanup_still_refuses_the_main_working_tree
    dropped = false

    WT.stub(:path_for_branch, '/dev/demarches-simplifiees.fr') do
      WT.stub(:main_path, '/dev/demarches-simplifiees.fr') do
        WT.stub(:drop_databases, ->(_names) { dropped = true }) do
          WT.cleanup('main')
        end
      end
    end

    refute dropped, 'the main working tree databases must never be dropped'
  end

  private

  def with_stubs(databases, worktrees, &block)
    WT.stub(:all_databases, databases) do
      WT.stub(:list, worktrees, &block)
    end
  end
end
