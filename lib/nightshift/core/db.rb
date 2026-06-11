module Nightshift
  def self.db
    @db ||= begin
      path = ENV.fetch("NIGHTSHIFT_DB_PATH")
      FileUtils.mkdir_p(File.dirname(path))
      db = Sequel.sqlite(path)
      db.run("PRAGMA journal_mode=WAL")
      db.run("PRAGMA foreign_keys=ON")
      Sequel::Migrator.run(db, File.join(__dir__, "../../db/migrations"))
      db
    end
  end
end
