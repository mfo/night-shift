require "minitest/autorun"
require "sequel"
require "sequel/extensions/migration"

TEST_DB = Sequel.sqlite
Sequel::Migrator.run(TEST_DB, File.join(__dir__, "../db/migrations"))

$LOAD_PATH.unshift(File.join(__dir__, "../lib"))
require "nightshift"
