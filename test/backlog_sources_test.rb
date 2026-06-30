# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'
require 'json'

HIGHEST = Nightshift::BacklogSources::Base::HIGHEST
HIGH    = Nightshift::BacklogSources::Base::HIGH
MEDIUM  = Nightshift::BacklogSources::Base::MEDIUM
LOW     = Nightshift::BacklogSources::Base::LOW
LOWEST  = Nightshift::BacklogSources::Base::LOWEST
LATER   = Nightshift::BacklogSources::Base::LATER

# --- Registry ---

class BacklogSourcesRegistryTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_for_returns_correct_class
    source = Nightshift::BacklogSources.for('haml-migration', @tmpdir)
    assert_instance_of Nightshift::BacklogSources::HamlMigration, source
  end

  def test_for_returns_nil_for_unknown_skill
    assert_nil Nightshift::BacklogSources.for('unknown-skill', @tmpdir)
  end

  def test_for_passes_repo_path
    source = Nightshift::BacklogSources.for('test-optimization', @tmpdir)
    assert_equal @tmpdir, source.repo_path
  end

  def test_registry_covers_all_known_skills
    expected = %w[haml-migration i18n-hardcoded test-optimization n1-query-fix flaky-test-fix]
    expected.each do |skill|
      refute_nil Nightshift::BacklogSources.for(skill, @tmpdir), "missing source for #{skill}"
    end
  end
end

# --- Base ---

class BacklogSourcesBaseTest < Minitest::Test
  def test_items_chains_scan_relevant_prioritize
    source = Class.new(Nightshift::BacklogSources::Base) do
      def scan = [{ item: 'a.rb' }, { item: 'b.rb' }, { item: 'c.rb' }]
      def relevant?(item_path) = item_path != 'b.rb'
      def prioritize(item) = item[:item] == 'a.rb' ? 5 : 1
    end.new('/tmp')

    items = source.items
    assert_equal 2, items.size
    assert_equal [{ item: 'a.rb', priority: 5 }, { item: 'c.rb', priority: 1 }], items
  end

  def test_default_relevant_returns_true
    source = Nightshift::BacklogSources::Base.new('/tmp')
    assert source.relevant?('anything.rb')
  end

  def test_default_prioritize_returns_zero
    source = Nightshift::BacklogSources::Base.new('/tmp')
    assert_equal 0, source.prioritize({ item: 'anything.rb' })
  end

  def test_scan_raises_not_implemented
    source = Nightshift::BacklogSources::Base.new('/tmp')
    assert_raises(NotImplementedError) { source.scan }
  end
end

# --- HamlMigration ---

class HamlMigrationSourceTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @source = Nightshift::BacklogSources::HamlMigration.new(@tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_scan_finds_haml_in_views
    write('app/views/users/show.html.haml', '%h1 Hello')
    write('app/views/admin/index.html.haml', '%p Admin')
    write('app/views/layouts/app.html.erb', '<html>')

    paths = @source.scan.map { |i| i[:item] }.sort
    assert_equal ['app/views/admin/index.html.haml', 'app/views/users/show.html.haml'], paths
  end

  def test_scan_finds_haml_in_components
    write('app/components/dossiers/row_component/row_component.html.haml', '%tr')
    write('app/components/dsfr/alert_component/alert_component.html.erb', '<div>')

    paths = @source.scan.map { |i| i[:item] }
    assert_equal ['app/components/dossiers/row_component/row_component.html.haml'], paths
  end

  def test_scan_returns_empty_when_no_haml
    write('app/views/show.html.erb', '<html>')
    assert_empty @source.scan
  end

  def test_priority_shared_is_highest
    assert_equal HIGHEST, @source.prioritize({ item: 'app/views/shared/dossiers/_header.html.haml' })
  end

  def test_priority_public_is_highest
    assert_equal HIGHEST, @source.prioritize({ item: 'app/views/root/index.html.haml' })
    assert_equal HIGHEST, @source.prioritize({ item: 'app/views/faq/show.html.haml' })
    assert_equal HIGHEST, @source.prioritize({ item: 'app/views/contact/index.html.haml' })
  end

  def test_priority_usagers_is_high
    assert_equal HIGH, @source.prioritize({ item: 'app/views/users/dossiers/show.html.haml' })
    assert_equal HIGH, @source.prioritize({ item: 'app/views/dossier_mailer/default.html.haml' })
    assert_equal HIGH, @source.prioritize({ item: 'app/components/editable_champ/text_component.html.haml' })
  end

  def test_priority_instructeurs_is_medium
    assert_equal MEDIUM, @source.prioritize({ item: 'app/views/instructeurs/dossiers/show.html.haml' })
    assert_equal MEDIUM, @source.prioritize({ item: 'app/views/experts/avis/index.html.haml' })
    assert_equal MEDIUM, @source.prioritize({ item: 'app/components/instructeurs/cell_component.html.haml' })
  end

  def test_priority_administrateurs_is_low
    assert_equal LOW, @source.prioritize({ item: 'app/views/administrateurs/procedures/show.html.haml' })
    assert_equal LOW, @source.prioritize({ item: 'app/components/procedure/card/attestation_component.html.haml' })
    assert_equal LOW, @source.prioritize({ item: 'app/components/types_de_champ_editor/block_component.html.haml' })
  end

  def test_priority_super_admin_is_later
    assert_equal LATER, @source.prioritize({ item: 'app/views/super_admins/release_notes/index.html.haml' })
    assert_equal LATER, @source.prioritize({ item: 'app/views/gestionnaires/index.html.haml' })
    assert_equal LATER, @source.prioritize({ item: 'app/views/layouts/mailers/notification.html.haml' })
  end

  def test_priority_unknown_defaults_to_medium
    assert_equal MEDIUM, @source.prioritize({ item: 'app/views/unknown/thing.html.haml' })
  end

  private

  def write(relative_path, content)
    path = File.join(@tmpdir, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end
end

# --- TestOptimization ---

class TestOptimizationSourceTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @source = Nightshift::BacklogSources::TestOptimization.new(@tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_scan_finds_spec_files
    write('spec/models/user_spec.rb', 'describe User')
    write('spec/system/login_spec.rb', 'describe "login"')
    write('app/models/user.rb', 'class User; end')

    paths = @source.scan.map { |i| i[:item] }.sort
    assert_equal ['spec/models/user_spec.rb', 'spec/system/login_spec.rb'], paths
  end

  def test_prioritize_with_profile
    write('spec/models/user_spec.rb', '')
    write_profile({ 'spec/models/user_spec.rb' => 45.2 })

    item = { item: 'spec/models/user_spec.rb' }
    assert_equal 8, @source.prioritize(item)
  end

  def test_prioritize_without_profile
    item = { item: 'spec/models/user_spec.rb' }
    assert_equal 0, @source.prioritize(item)
  end

  def test_prioritize_tiers
    write_profile({
      'spec/fast_spec.rb' => 0.5,
      'spec/medium_spec.rb' => 3,
      'spec/slow_spec.rb' => 20,
      'spec/very_slow_spec.rb' => 65
    })

    assert_equal 2, @source.prioritize({ item: 'spec/fast_spec.rb' })
    assert_equal 2, @source.prioritize({ item: 'spec/medium_spec.rb' })
    assert_equal 6, @source.prioritize({ item: 'spec/slow_spec.rb' })
    assert_equal 10, @source.prioritize({ item: 'spec/very_slow_spec.rb' })
  end

  def test_items_integrates_scan_and_prioritize
    write('spec/models/user_spec.rb', '')
    write('spec/system/login_spec.rb', '')
    write_profile({ 'spec/system/login_spec.rb' => 90.0 })

    items = @source.items
    assert_equal 2, items.size

    login = items.find { |i| i[:item] == 'spec/system/login_spec.rb' }
    user = items.find { |i| i[:item] == 'spec/models/user_spec.rb' }

    assert_equal 10, login[:priority]
    assert_equal 0, user[:priority]
  end

  def test_corrupted_profile_json
    write_raw('tmp/rspec_profile.json', 'not json{{{')
    assert_equal 0, @source.prioritize({ item: 'spec/any_spec.rb' })
  end

  private

  def write(relative_path, content)
    path = File.join(@tmpdir, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def write_profile(data)
    write_raw('tmp/rspec_profile.json', JSON.generate(data))
  end

  def write_raw(relative_path, content)
    path = File.join(@tmpdir, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end
end

# --- N1QueryFix ---

class N1QueryFixSourceTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @source = Nightshift::BacklogSources::N1QueryFix.new(@tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_scan_parses_prosopite_log
    write('app/models/user.rb', 'class User; end')
    write_prosopite(<<~LOG)
      SELECT "dossiers".* FROM "dossiers" WHERE "dossiers"."user_id" = 1
      app/models/user.rb:10:in `dossiers'
      app/controllers/users_controller.rb:5:in `show'

    LOG

    items = @source.scan
    assert_equal 1, items.size
    assert_equal 'app/models/user.rb', items.first[:item]
  end

  def test_scan_returns_empty_without_prosopite
    assert_empty @source.scan
  end

  def test_scan_groups_patterns_by_model
    write('app/models/dossier.rb', '')
    write_prosopite(<<~LOG)
      SELECT "commentaires".* FROM "commentaires" WHERE "commentaires"."dossier_id" = 1
      app/models/dossier.rb:20:in `commentaires'

      SELECT "avis".* FROM "avis" WHERE "avis"."dossier_id" = 1
      app/models/dossier.rb:30:in `avis'

    LOG

    items = @source.scan
    assert_equal 1, items.size
    assert_equal 'app/models/dossier.rb', items.first[:item]

    context = JSON.parse(items.first[:context], symbolize_names: true)
    assert_equal 2, context[:n1_patterns].size
  end

  def test_scan_finds_model_from_table_name
    write('app/models/commentaire.rb', '')
    write_prosopite(<<~LOG)
      SELECT "commentaires".* FROM "commentaires" WHERE "commentaires"."dossier_id" = 1
      app/controllers/dossiers_controller.rb:10:in `show'

    LOG

    items = @source.scan
    assert_equal 1, items.size
    assert_equal 'app/models/commentaire.rb', items.first[:item]
  end

  def test_scan_finds_model_from_call_stack
    write('app/models/concerns/notifiable.rb', '')
    write_prosopite(<<~LOG)
      SELECT "notifications".* FROM "notifications" WHERE "notifications"."user_id" = 1
      app/models/concerns/notifiable.rb:15:in `pending_notifications'

    LOG

    items = @source.scan
    assert_equal 1, items.size
    assert_equal 'app/models/concerns/notifiable.rb', items.first[:item]
  end

  def test_scan_skips_patterns_without_model
    write_prosopite(<<~LOG)
      SELECT "ghost_table".* FROM "ghost_table" WHERE "ghost_table"."id" = 1
      app/controllers/foo_controller.rb:5:in `index'

    LOG

    assert_empty @source.scan
  end

  def test_prioritize_by_waste_ms
    cases = [
      [0, 0],
      [100, 1],
      [500, 3],
      [1_000, 5],
      [3_000, 7],
      [5_000, 8],
      [10_000, 10]
    ]

    cases.each do |waste, expected|
      ctx = JSON.generate({ total_waste_ms: waste })
      assert_equal expected, @source.prioritize({ item: 'x.rb', context: ctx }),
        "waste=#{waste} should give priority #{expected}"
    end
  end

  def test_scan_with_skylight_data
    write('app/models/dossier.rb', '')
    write_prosopite(<<~LOG)
      SELECT "commentaires".* FROM "commentaires" WHERE "commentaires"."dossier_id" = 1
      app/models/dossier.rb:20:in `commentaires'
      app/controllers/dossiers_controller.rb:10:in `show'

    LOG
    write_skylight([{
      'name' => 'DossiersController#show',
      'count' => 600,
      'latencyP95' => 250
    }])

    items = @source.scan
    context = JSON.parse(items.first[:context], symbolize_names: true)
    assert context[:total_waste_ms] > 0
    assert_equal 1, context[:n1_patterns].first[:endpoints].size
  end

  private

  def write(relative_path, content)
    path = File.join(@tmpdir, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def write_prosopite(content)
    write('tmp/prosopite.log', content)
  end

  def write_skylight(endpoints)
    write('tmp/skylight-endpoints.json', JSON.generate({ 'endpoints' => endpoints }))
  end
end

# --- FlakyTestFix ---

class FlakyTestFixSourceTest < Minitest::Test
  def test_prioritize_merge_queue_heavy
    ctx = JSON.generate({ merge_queue_count: 6, retry_count: 2 })
    source = Nightshift::BacklogSources::FlakyTestFix.new('/tmp')
    assert_equal 10, source.prioritize({ item: 'spec/x_spec.rb', context: ctx })
  end

  def test_prioritize_retry_only
    ctx = JSON.generate({ merge_queue_count: 0, retry_count: 3 })
    source = Nightshift::BacklogSources::FlakyTestFix.new('/tmp')
    assert_equal 4, source.prioritize({ item: 'spec/x_spec.rb', context: ctx })
  end

  def test_prioritize_critical
    ctx = JSON.generate({ merge_queue_count: 10, retry_count: 5 })
    source = Nightshift::BacklogSources::FlakyTestFix.new('/tmp')
    assert_equal 10, source.prioritize({ item: 'spec/x_spec.rb', context: ctx })
  end

  def test_prioritize_low
    ctx = JSON.generate({ merge_queue_count: 0, retry_count: 1 })
    source = Nightshift::BacklogSources::FlakyTestFix.new('/tmp')
    assert_equal 2, source.prioritize({ item: 'spec/x_spec.rb', context: ctx })
  end

  def test_prioritize_zero
    ctx = JSON.generate({ merge_queue_count: 0, retry_count: 0 })
    source = Nightshift::BacklogSources::FlakyTestFix.new('/tmp')
    assert_equal 0, source.prioritize({ item: 'spec/x_spec.rb', context: ctx })
  end
end
