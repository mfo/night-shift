# frozen_string_literal: true

require_relative 'test_helper'
require 'open3'
require 'minitest/mock'

# `Worktree` defaultait ses neuf methodes sur le repo hote, et quinze appelants
# les invoquaient sans argument. Une branche vivant ailleurs etait donc
# invisible : `path_for_branch` rendait nil (d'ou WorktreeError au lancement),
# et `health_check` la classait zombie a chaque tick.
#
# Plutot que de faire remonter un `repo_path` par quinze sites qui n'ont qu'une
# branche en main, on le resout depuis le nom de la branche.
class RepoResolutionTest < Minitest::Test
  def setup
    @original = Nightshift.config
    Nightshift.config = build_config
  end

  def teardown
    Nightshift.config = @original
  end

  def test_auto_branch_resolves_to_the_skill_repo
    assert_equal '/tmp/doc-repo',
                 Nightshift.repo_path_for_branch('auto/doc-release-sync/2026-09-08-01')
  end

  def test_auto_branch_of_a_host_skill_resolves_to_the_host
    assert_equal '/tmp/host-repo',
                 Nightshift.repo_path_for_branch('auto/haml-migration/views-foo')
  end

  # Une branche humaine n'a pas de skill : elle appartient au repo hote.
  def test_non_auto_branch_falls_back_to_host
    assert_equal '/tmp/host-repo', Nightshift.repo_path_for_branch('fix/some-bug')
    assert_equal '/tmp/host-repo', Nightshift.repo_path_for_branch('main')
  end

  # Un skill retire du YAML ne doit pas faire exploser le nettoyage des
  # worktrees qu'il a laisses derriere lui.
  def test_unknown_skill_in_branch_falls_back_to_host
    assert_equal '/tmp/host-repo', Nightshift.repo_path_for_branch('auto/skill-disparu/x')
  end

  def test_repo_for_skill_defaults_to_host
    assert_equal 'app', Nightshift.repo_for('haml-migration').name
    assert_equal 'doc', Nightshift.repo_for('doc-release-sync').name
  end

  # `repos` doit etre total : un Config construit par morceaux — ce que font
  # les stubs de test, et ce que ferait un chemin d'initialisation partiel —
  # ne doit pas faire exploser la resolution. La regression s'est produite :
  # un test du Reconciler stubbait Config sans `@repos` et cassait
  # `health_check`, de facon intermittente selon l'ordre d'execution.
  def test_repos_is_total_even_on_a_partial_config
    partial = Nightshift::Config.allocate
    partial.instance_variable_set(:@repo_path, '/tmp/partiel')

    assert_equal '/tmp/partiel', partial.repos.fetch('app').path
    assert_equal '/tmp/partiel', partial.repo_path_for('un-skill-inconnu')
  end

  # `cleanup` et `path_for_branch` resolvent desormais le repo depuis la
  # branche. C'est ce qui repare `nightshift worktree close` sur une branche
  # vivant hors du repo hote : avant, il marquait l'item `Failed(ManualClose)`
  # puis nettoyait le mauvais depot — le worktree et la branche survivaient, et
  # `worktree reset` bouclait ensuite sur « branche deja existante ».
  def test_cleanup_targets_the_repo_of_the_branch
    seen = []
    # `all_databases` interroge le statut de sortie : un stub qui rend nil
    # ferait echouer la lecture plutot que le test.
    ok = Struct.new(:success?).new(true)

    Open3.stub(:capture2, ->(*args, **_) { seen << args; ['', ok] }) do
      Nightshift::Integrations::Worktree.cleanup('auto/doc-release-sync/2026-09-08-01')
    end

    repos_consulted = seen.select { |a| a.include?('-C') }.map { |a| a[a.index('-C') + 1] }
    assert_includes repos_consulted, '/tmp/doc-repo'
    refute_includes repos_consulted, '/tmp/host-repo'
  end

  # Les deux pieges du predicat, dans les deux sens. Une allowlist naive en
  # `start_with?` laisserait passer `apparence.rb` sur le prefixe `app` ; une
  # construction en `^(a|b)/` ferait disparaitre `SUMMARY.md`, precisement le
  # fichier qu'une PR de doc doit pouvoir modifier seule.
  def test_content_predicate_handles_root_files_and_prefixes
    app = Nightshift.repo_for('haml-migration')
    assert app.content?('lib/nightshift.rb')
    refute app.content?('libre/service.rb'), 'prefixe sans separateur'
    refute app.content?('README.md')

    doc = Nightshift.repo_for('doc-release-sync')
    assert doc.content?('SUMMARY.md'), 'un fichier racine doit compter'
    assert doc.content?('api-graphql/README.md')
    refute doc.content?('.gitbook/assets/capture.png')
  end

  private

  def build_config
    Nightshift::Config.allocate.tap do |c|
      c.instance_variable_set(:@repo_path, '/tmp/host-repo')
      c.instance_variable_set(:@skills, { 'doc-release-sync' => { repo: 'doc' } })
      c.instance_variable_set(:@repos, {
        'app' => Nightshift::Core::Repo.new(name: 'app', path: '/tmp/host-repo',
                                            content_allow: %w[lib]),
        'doc' => Nightshift::Core::Repo.new(name: 'doc', path: '/tmp/doc-repo',
                                            content_deny: %w[.gitbook])
      })
    end
  end
end
