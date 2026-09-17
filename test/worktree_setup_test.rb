# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'

# `Worktree.setup` n'avait aucun appelant : le `.claude/` des worktrees etait
# pose par le hook post-checkout, installe dans le repo applicatif. Un worktree
# ouvert sur un autre repo n'en recevait donc rien, et `/<skill>` y etait une
# commande inconnue — 0 tour, 0 commit, no_diff, Judge. Le mode d'echec le plus
# repete de l'historique kaizen.
class WorktreeSetupTest < Minitest::Test
  def test_copies_everything_when_the_repo_declares_no_filter
    in_worktree do |wt|
      Nightshift::Integrations::Worktree.setup(wt, repo(skills: nil, agents: nil))

      assert File.exist?(File.join(wt, '.claude/skills/doc-pr-analyzer/SKILL.md'))
      assert File.exist?(File.join(wt, '.claude/agents/doc-pr-analyzer.md'))
    end
  end

  def test_copies_only_the_declared_entries
    in_worktree do |wt|
      Nightshift::Integrations::Worktree.setup(
        wt, repo(skills: ['doc-pr-analyzer'], agents: ['doc-pr-analyzer'])
      )

      assert File.exist?(File.join(wt, '.claude/skills/doc-pr-analyzer/SKILL.md'))
      refute File.exist?(File.join(wt, '.claude/skills/haml-migration')),
             'un skill non declare ne doit pas etre embarque'
    end
  end

  # Les agents etaient exclus en dur des deux mecanismes de provisioning. Un
  # skill qui delegue a un sous-agent le trouvait donc absent du worktree.
  def test_agents_can_be_embarked
    in_worktree do |wt|
      Nightshift::Integrations::Worktree.setup(wt, repo(skills: [], agents: ['doc-pr-analyzer']))

      assert File.exist?(File.join(wt, '.claude/agents/doc-pr-analyzer.md'))
    end
  end

  # `settings.json` est versionne dans les repos cibles : l'ecraser supprimerait
  # leurs regles de permissions, et « permission denied loop » est un motif
  # recurrent du kaizen.
  def test_never_overwrites_settings_json
    in_worktree do |wt|
      target = File.join(wt, '.claude')
      FileUtils.mkdir_p(target)
      File.write(File.join(target, 'settings.json'), '{"permissions":"a-moi"}')

      Nightshift::Integrations::Worktree.setup(wt, repo(skills: [], agents: []))

      assert_equal '{"permissions":"a-moi"}', File.read(File.join(target, 'settings.json'))
    end
  end

  # Une entree demandee mais absente doit etre signalee : c'est exactement ce
  # qui produit un *Unknown command* silencieux dans le worktree.
  def test_warns_when_a_declared_entry_is_missing
    in_worktree do |wt|
      out, = capture_subprocess_io do
        Nightshift::Integrations::Worktree.setup(wt, repo(skills: ['skill-fantome'], agents: []))
      end
      refute File.exist?(File.join(wt, '.claude/skills/skill-fantome'))
      assert_match(/skill-fantome/, out + $stderr.to_s) if out
    end
  end

  private

  def repo(skills:, agents:)
    Nightshift::Core::Repo.new(name: 'doc', path: '/tmp', content_deny: %w[tmp],
                               worktree_skills: skills, worktree_agents: agents)
  end

  def in_worktree(&)
    Dir.mktmpdir('ns-wt', &)
  end
end
