abort "nightshift: Ruby 3.3+ required (you have #{RUBY_VERSION})" if RUBY_VERSION < "3.3"

require "dotenv/load"
require "sequel"
require "sequel/extensions/migration"
require "fileutils"

require_relative "nightshift/db"
require_relative "nightshift/pr"
require_relative "nightshift/store"
require_relative "nightshift/github"
require_relative "nightshift/reconciler"
require_relative "nightshift/brief"
require_relative "nightshift/diagnose"
require_relative "nightshift/autofix"
require_relative "nightshift/skill_loader"
require_relative "nightshift/skill_runner"
require_relative "nightshift/renderer"
require_relative "nightshift/attach"
require_relative "nightshift/cli"

module Nightshift
end
