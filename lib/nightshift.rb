abort "nightshift: Ruby 3.3+ required (you have #{RUBY_VERSION})" if RUBY_VERSION < "3.3"

require "dotenv/load"
require "sequel"
require "sequel/extensions/migration"
require "fileutils"

module Nightshift
  SKILLS = {
    "haml-migration"    => { scan: "app/views/**/*.html.haml", needs_server: true },
    "test-optimization" => { scan: "spec/**/*_spec.rb",
                             inventory: File.expand_path("../../pocs/test-optimization/slow-tests-inventory.md", __FILE__) }
  }.freeze

  BASE_PORT = 3001

  def self.skill_names = SKILLS.keys

  def self.count_turns(log_path)
    return nil unless File.exist?(log_path)
    File.read(log_path).scan(/"type"\s*:\s*"assistant"/).size
  rescue StandardError
    nil
  end
end

require_relative "nightshift/db"
require_relative "nightshift/worktree"
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
