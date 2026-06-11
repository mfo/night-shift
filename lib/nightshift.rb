abort "nightshift: Ruby 3.3+ required (you have #{RUBY_VERSION})" if RUBY_VERSION < "3.3"

require "dotenv/load"
require "sequel"
require "sequel/extensions/migration"
require "fileutils"
require "zeitwerk"

module Nightshift
  SKILLS = {
    "haml-migration"    => { scan: "app/views/**/*.html.haml", needs_server: true, port: 3210 },
    "test-optimization" => { scan: "spec/**/*_spec.rb" },
    "i18n-hardcoded"    => {
      scan: "app/{mailers,components}/**/*.{rb,html.erb}",
      needs_server: true, port: 3220,
      priority_map: {
        %r{/dossiers/|/users/|quotient_familial|notification_mailer|user_mailer|phishing_alert} => 3,
        %r{/instructeurs?/|instructeur_mailer|expert_mailer|avis_mailer|invite_mailer} => 2
      }
    },
    "n1-query-fix"      => {
      scan_proc: ->(repo_path, store) {
        Integrations::N1Scanner.scan(repo_path, store)
      }
    },
    "reprioritize"      => { meta: true }
  }

  def self.skill_names = SKILLS.keys

  def self.db
    @db ||= begin
      path = ENV.fetch("NIGHTSHIFT_DB_PATH")
      FileUtils.mkdir_p(File.dirname(path))
      db = Sequel.sqlite(path)
      db.run("PRAGMA journal_mode=WAL")
      db.run("PRAGMA foreign_keys=ON")
      Sequel::Migrator.run(db, File.join(__dir__, "../db/migrations"))
      db
    end
  end

  def self.reload!
    Zeitwerk::Loader.eager_load_all
  end

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

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "ci" => "CI",
  "cli" => "CLI",
  "pr" => "PR",
  "ui" => "UI",
  "github" => "GitHub"
)
loader.setup
