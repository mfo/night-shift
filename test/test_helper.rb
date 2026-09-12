# frozen_string_literal: true

require 'minitest/autorun'
require 'sequel'
require 'sequel/extensions/migration'

TEST_DB = Sequel.sqlite
Sequel::Migrator.run(TEST_DB, File.join(__dir__, '../db/migrations'))

$LOAD_PATH.unshift(File.join(__dir__, '../lib'))
require 'nightshift'

# Stub config for tests — no YAML file needed
Nightshift.config = Nightshift::Config.allocate.tap do |c|
  c.instance_variable_set(:@repo_path, '/tmp/test-repo')
  c.instance_variable_set(:@backends, {
    'default' => Nightshift::Core::LLMBackend.new(name: 'default', harness: 'claude', concurrency: 4)
  })
  c.instance_variable_set(:@default_backend_name, 'default')
  c.instance_variable_set(:@skills, {
    'haml-migration' => { scan: 'app/views/**/*.html.haml', needs_server: true, port: 3210 },
    'test-optimization' => { scan: 'spec/**/*_spec.rb' },
    'i18n-hardcoded' => { scan: 'app/{mailers,components}/**/*.{rb,html.erb}', needs_server: true, port: 3220 },
    'n1-query-fix' => {},
    'reprioritize' => { meta: true }
  })
  # Sans `@repos`, `repo_for` leverait des que le harness l'appellera.
  c.instance_variable_set(:@repos, {
    'app' => Nightshift::Core::Repo.new(
      name: 'app', path: '/tmp/test-repo',
      content_allow: Nightshift::Config::DEFAULT_CONTENT_ALLOW.dup
    )
  })
end

Nightshift.instance_variable_set(:@db, TEST_DB)

# La migration 011 pose une FK `backlog_items.pr_number` -> `prs.number`.
# Tout test qui rattache un item a une PR doit donc creer la ligne `prs`
# correspondante, exactement comme le fait Pipeline#push_and_create_pr en prod.
module PRFixture
  def seed_pr(number, branch: nil, **attrs)
    pr = Nightshift::Core::PR.new(
      number: number,
      branch: branch || "fix/bug-#{number}",
      github_state: 'OPEN',
      ci: 'red',
      **attrs
    )
    # Chaque classe de test monte sa propre base dans `setup` ; on ecrit donc
    # via le store du test, jamais via TEST_DB.
    @store.upsert(pr)
    number
  end
end

Minitest::Test.include(PRFixture)

# Force-load all classes upfront so Sorbet sig blocks don't trigger
# Zeitwerk autoloads mid-test (which causes T::Struct redefinition errors).
Zeitwerk::Loader.eager_load_all
