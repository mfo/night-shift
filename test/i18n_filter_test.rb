# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'

class I18nFilterTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  # --- ERB ---

  def test_erb_with_hardcoded_french
    write('app/views/foo.html.erb', <<~ERB)
      <div>
        <h1>Bienvenue sur la plateforme</h1>
        <p><%= @user.name %></p>
      </div>
    ERB

    assert Nightshift::Integrations::I18nFilter.hardcoded?(@tmpdir, 'app/views/foo.html.erb')
  end

  def test_erb_fully_i18nized
    write('app/views/foo.html.erb', <<~ERB)
      <div>
        <h1><%= t('.welcome') %></h1>
        <p><%= @user.name %></p>
      </div>
    ERB

    refute Nightshift::Integrations::I18nFilter.hardcoded?(@tmpdir, 'app/views/foo.html.erb')
  end

  def test_erb_with_only_erb_tags
    write('app/views/foo.html.erb', <<~ERB)
      <div>
        <%= render partial: 'shared/header' %>
        <% if @user.present? %>
          <%= @user.email %>
        <% end %>
      </div>
    ERB

    refute Nightshift::Integrations::I18nFilter.hardcoded?(@tmpdir, 'app/views/foo.html.erb')
  end

  def test_erb_with_mixed_i18n_and_hardcoded
    write('app/views/foo.html.erb', <<~ERB)
      <h1><%= t('.title') %></h1>
      <p>Veuillez remplir le formulaire</p>
    ERB

    assert Nightshift::Integrations::I18nFilter.hardcoded?(@tmpdir, 'app/views/foo.html.erb')
  end

  # --- Ruby ---

  def test_rb_with_hardcoded_french_string
    write('app/components/foo.rb', <<~RUBY)
      class FooComponent < ApplicationComponent
        def message
          "Votre dossier est en cours"
        end
      end
    RUBY

    assert Nightshift::Integrations::I18nFilter.hardcoded?(@tmpdir, 'app/components/foo.rb')
  end

  def test_rb_with_no_french_strings
    write('app/components/foo.rb', <<~RUBY)
      class FooComponent < ApplicationComponent
        def message
          t('.message')
        end

        def css_class
          "btn btn-primary"
        end
      end
    RUBY

    refute Nightshift::Integrations::I18nFilter.hardcoded?(@tmpdir, 'app/components/foo.rb')
  end

  def test_rb_ignores_comments
    write('app/components/foo.rb', <<~RUBY)
      # Ce composant affiche le formulaire
      class FooComponent < ApplicationComponent
        def render?
          true
        end
      end
    RUBY

    refute Nightshift::Integrations::I18nFilter.hardcoded?(@tmpdir, 'app/components/foo.rb')
  end

  def test_rb_ignores_i18n_keys
    write('app/components/foo.rb', <<~RUBY)
      class FooComponent < ApplicationComponent
        def label
          "shared.components.label"
        end
      end
    RUBY

    refute Nightshift::Integrations::I18nFilter.hardcoded?(@tmpdir, 'app/components/foo.rb')
  end

  # --- HAML ---

  def test_haml_with_hardcoded_text
    write('app/views/foo.html.haml', <<~HAML)
      .container
        %h1 Bienvenue sur votre espace
        = render 'shared/nav'
    HAML

    assert Nightshift::Integrations::I18nFilter.hardcoded?(@tmpdir, 'app/views/foo.html.haml')
  end

  def test_haml_fully_i18nized
    write('app/views/foo.html.haml', <<~HAML)
      .container
        %h1= t('.welcome')
        = render 'shared/nav'
    HAML

    refute Nightshift::Integrations::I18nFilter.hardcoded?(@tmpdir, 'app/views/foo.html.haml')
  end

  # --- ERB attributes ---

  def test_erb_hardcoded_placeholder
    write('app/views/foo.html.erb', <<~ERB)
      <input type="text" placeholder="Entrez votre nom" />
    ERB

    assert Nightshift::Integrations::I18nFilter.hardcoded?(@tmpdir, 'app/views/foo.html.erb')
  end

  def test_erb_hardcoded_title
    write('app/views/foo.html.erb', <<~ERB)
      <a href="/" title="Retour au tableau de bord">Home</a>
    ERB

    assert Nightshift::Integrations::I18nFilter.hardcoded?(@tmpdir, 'app/views/foo.html.erb')
  end

  def test_erb_i18nized_placeholder
    write('app/views/foo.html.erb', <<~ERB)
      <input type="text" placeholder="<%= t('.placeholder') %>" />
    ERB

    refute Nightshift::Integrations::I18nFilter.hardcoded?(@tmpdir, 'app/views/foo.html.erb')
  end

  def test_erb_data_confirm
    write('app/views/foo.html.erb', <<~ERB)
      <button data-confirm="Voulez vous vraiment supprimer">Delete</button>
    ERB

    assert Nightshift::Integrations::I18nFilter.hardcoded?(@tmpdir, 'app/views/foo.html.erb')
  end

  def test_erb_no_translatable_attrs
    write('app/views/foo.html.erb', <<~ERB)
      <div class="container" id="main">
        <%= render 'content' %>
      </div>
    ERB

    refute Nightshift::Integrations::I18nFilter.hardcoded?(@tmpdir, 'app/views/foo.html.erb')
  end

  # --- Edge cases ---

  def test_missing_file
    refute Nightshift::Integrations::I18nFilter.hardcoded?(@tmpdir, 'nonexistent.html.erb')
  end

  def test_empty_file
    write('app/views/empty.html.erb', '')
    refute Nightshift::Integrations::I18nFilter.hardcoded?(@tmpdir, 'app/views/empty.html.erb')
  end

  def test_unsupported_extension
    write('app/assets/foo.js', 'const msg = "Bonjour le monde"')
    refute Nightshift::Integrations::I18nFilter.hardcoded?(@tmpdir, 'app/assets/foo.js')
  end

  private

  def write(relative_path, content)
    path = File.join(@tmpdir, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end
end
