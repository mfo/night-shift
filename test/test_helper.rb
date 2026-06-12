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
  c.instance_variable_set(:@skills, {
    'haml-migration' => { scan: 'app/views/**/*.html.haml', needs_server: true, port: 3210 },
    'test-optimization' => { scan: 'spec/**/*_spec.rb' },
    'i18n-hardcoded' => { scan: 'app/{mailers,components}/**/*.{rb,html.erb}', needs_server: true, port: 3220 },
    'n1-query-fix' => {},
    'reprioritize' => { meta: true }
  })
end

Nightshift.instance_variable_set(:@db, TEST_DB)

# Force-load all classes upfront so Sorbet sig blocks don't trigger
# Zeitwerk autoloads mid-test (which causes T::Struct redefinition errors).
Zeitwerk::Loader.eager_load_all
