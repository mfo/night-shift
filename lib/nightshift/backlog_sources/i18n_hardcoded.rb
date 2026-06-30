# frozen_string_literal: true

require 'nokogiri'

module Nightshift
  module BacklogSources
    class I18nHardcoded < Base
      FRENCH_PATTERN = /[A-ZÀ-Ÿa-zà-ÿ]{2,}\s+[a-zà-ÿ]{2,}/
      ACCENTED = /[À-ÖØ-öø-ÿ]/
      FRENCH_WORDS = /\b(votre|notre|vous|nous|est|sont|les|des|une|pour|dans|sur|avec|pas|qui|que|ont|aux|ses|ces|leur|mais|donc|car|puis|aussi|cette|tout|tous|aucun|chaque|entre|depuis|après|avant|selon|comme|sans|sous|chez|vers|doit|peut|veuillez|merci|bonjour|bienvenue|erreur|formulaire|dossier|compte|espace)\b/i
      TRANSLATABLE_ATTRS = %w[placeholder title alt aria-label data-confirm].freeze

      sig { override.returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def scan
        glob('app/{mailers,components}/**/*.{rb,html.erb}')
      end

      sig { override.params(item_path: String).returns(T::Boolean) }
      def relevant?(item_path)
        path = File.join(repo_path, item_path)
        return false unless File.exist?(path)

        content = File.read(path, encoding: 'utf-8')
        return false if content.empty?

        if item_path.end_with?('.html.erb')
          hardcoded_erb?(content)
        elsif item_path.end_with?('.rb')
          hardcoded_rb?(content)
        elsif item_path.end_with?('.html.haml')
          hardcoded_haml?(content)
        else
          false
        end
      rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
        false
      end

      sig { override.params(item: T::Hash[Symbol, T.untyped]).returns(Integer) }
      def prioritize(item)
        prioritize_by_view_path(item[:item])
      end

      private

      sig { params(content: String).returns(T::Boolean) }
      def hardcoded_erb?(content)
        stripped = content
          .gsub(/<%=.*?%>/m, ' ')
          .gsub(/<%.*?%>/m, '')

        doc = Nokogiri::HTML.fragment(stripped)

        doc.traverse do |node|
          if node.text?
            return true if french_text?(node.text)
          elsif node.element?
            TRANSLATABLE_ATTRS.each do |attr|
              val = node[attr]
              return true if val && french_text?(val)
            end
          end
        end

        false
      end

      sig { params(content: String).returns(T::Boolean) }
      def hardcoded_rb?(content)
        lines = content.lines.reject { |l| l.strip.start_with?('#') }
        text = lines.join
        strings = text.scan(/"([^"]*)"/).flatten + text.scan(/'([^']*)'/).flatten

        strings.any? { |s| s.match?(FRENCH_PATTERN) && (s.match?(ACCENTED) || s.match?(FRENCH_WORDS)) }
      end

      sig { params(content: String).returns(T::Boolean) }
      def hardcoded_haml?(content)
        i18n_call = /\bt\(|I18n\.t\(/
        lines = content.lines
          .reject { |l| l.strip.start_with?('-') }
          .reject { |l| l.strip.match?(/^=\s/) }
          .reject { |l| l.strip.match?(i18n_call) }

        lines.join.match?(FRENCH_PATTERN)
      end

      sig { params(text: String).returns(T::Boolean) }
      def french_text?(text)
        text.strip.match?(FRENCH_PATTERN)
      end
    end
  end
end
