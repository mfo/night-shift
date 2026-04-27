abort "nightshift: Ruby 3.3+ required (you have #{RUBY_VERSION})" if RUBY_VERSION < "3.3"

require "dotenv/load"
require "sequel"
require "sequel/extensions/migration"
require "fileutils"

module Nightshift
  SKILLS = {
    "haml-migration"    => { scan: "app/views/**/*.html.haml", needs_server: true, port: 3210 },
    "test-optimization" => { scan: "spec/**/*_spec.rb" }
  }.freeze

  def self.skill_names = SKILLS.keys

  def self.count_turns(log_path)
    return nil unless File.exist?(log_path)
    File.read(log_path).scan(/"type"\s*:\s*"assistant"/).size
  rescue StandardError
    nil
  end

  # Fuzzy-readable slug: dir initials + filename, tronqué pour rester
  # compatible avec les sockets Unix (104 chars max sur macOS).
  # overmind-auto-<skill>-<slug>-<22 chars> ≤ 104
  # → slug max = 71 - len("auto-") - len(skill) - 1
  MAX_WORKTREE_DIR = 50  # safe default: auto-<skill>-<slug> ≤ ~70 chars

  def self.short_slug(path, skill_name: nil)
    parts = path.sub(%r{^(app|spec)/}, "").split("/")
    filename = parts.pop
    filename = filename.sub(/(_spec)?\.rb$/, "").sub(/\.html\.haml$/, "")
    dirs = parts.map { |d| d[0] }
    slug = (dirs + [filename]).join("-")

    # Tronquer si le worktree dir serait trop long (socket Unix limit)
    prefix_len = "auto-#{skill_name}-".length if skill_name
    max_slug = prefix_len ? (MAX_WORKTREE_DIR - prefix_len) : 30

    if slug.length > max_slug
      require "digest"
      hash = Digest::SHA1.hexdigest(path)[0, 6]
      slug = "#{slug[0, max_slug - 7]}-#{hash}"
    end

    slug
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
require_relative "nightshift/judge"
require_relative "nightshift/skill_pipeline"
require_relative "nightshift/autolearn_monitor"
require_relative "nightshift/renderer"
require_relative "nightshift/attach"
require_relative "nightshift/cli"
