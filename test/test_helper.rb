# frozen_string_literal: true

require 'minitest/autorun'
require 'sequel'
require 'sequel/extensions/migration'

TEST_DB = Sequel.sqlite
Sequel::Migrator.run(TEST_DB, File.join(__dir__, '../db/migrations'))

$LOAD_PATH.unshift(File.join(__dir__, '../lib'))
require 'nightshift'

# Force-load all classes upfront so Sorbet sig blocks don't trigger
# Zeitwerk autoloads mid-test (which causes T::Struct redefinition errors).
Zeitwerk::Loader.eager_load_all
