# frozen_string_literal: true

require_relative 'test_helper'
require 'tempfile'

# Minitest ne collecte que les methodes publiques commençant par `test_`. Une
# methode de test ecrite sous `private` est ignoree en silence : pas d'erreur,
# pas d'avertissement, juste un test qui ne tourne jamais et une suite qui
# reste verte. Le piege s'est referme deux fois pendant le chantier
# DocReleaseSync, a chaque fois en ancrant un ajout sur un helper prive.
class TestHygieneTest < Minitest::Test
  def test_no_test_method_is_declared_private
    # Ce fichier porte un fixture volontairement fautif dans un heredoc, que
    # le scanner ne peut pas distinguer du vrai code.
    offenders = Dir[File.join(__dir__, '*_test.rb')]
                .reject { |path| File.basename(path) == File.basename(__FILE__) }
                .flat_map { |path| scan_private_tests(path) }

    assert_empty offenders,
                 "ces tests sont sous `private` et ne tourneront jamais :\n  " \
                 "#{offenders.join("\n  ")}"
  end

  # Verifie que le detecteur detecte : sans ça, un garde-fou casse laisse
  # passer exactement ce qu'il surveille.
  def test_detector_flags_a_private_test
    Tempfile.create(['probe', '_test.rb']) do |f|
      f.write(<<~RUBY)
        class ProbeTest < Minitest::Test
          def test_visible; end
          private
          def test_hidden; end
        end
      RUBY
      f.flush

      found = scan_private_tests(f.path)
      assert_equal 1, found.size
      assert_includes found.first, 'test_hidden'
    end
  end

  private

  # `private` est portee par classe : une nouvelle declaration de classe
  # reouvre la visibilite publique, et un fichier qui en contient plusieurs
  # (comme backlog_sources_test.rb) donnerait sinon des faux positifs.
  def scan_private_tests(path)
    private_seen = false
    bad = []

    File.readlines(path).each_with_index do |line, idx|
      private_seen = false if line.match?(/^\s*class\s+\w+/)
      private_seen = true  if line.match?(/^\s*private\s*$/)

      next unless private_seen
      next unless (m = line.match(/^\s*def\s+(test_\w+)/))

      bad << "#{File.basename(path)}:#{idx + 1} #{m[1]}"
    end

    bad
  end
end
