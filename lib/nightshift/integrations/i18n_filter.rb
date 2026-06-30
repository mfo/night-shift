# frozen_string_literal: true

require 'nokogiri'

module Nightshift
  module Integrations
    #
    # I18nFilter — Detect files containing hardcoded text (not i18n-ized)
    #
    # Uses Nokogiri to parse ERB/HAML templates after stripping Ruby tags,
    # then checks text nodes and translatable attributes for hardcoded text.
    #
    module I18nFilter
      module_function

      FRENCH_PATTERN = /[A-ZÀ-Ÿa-zà-ÿ]{2,}\s+[a-zà-ÿ]{2,}/
      ACCENTED = /[À-ÖØ-öø-ÿ]/
      FRENCH_WORDS = /\b(votre|notre|vous|nous|est|sont|les|des|une|pour|dans|sur|avec|pas|qui|que|ont|aux|ses|ces|leur|mais|donc|car|puis|aussi|cette|tout|tous|aucun|chaque|entre|depuis|après|avant|selon|comme|sans|sous|chez|vers|doit|peut|veuillez|merci|bonjour|bienvenue|erreur|formulaire|dossier|compte|espace)\b/i
      I18N_CALL = /\bt\(|I18n\.t\(/
      TRANSLATABLE_ATTRS = %w[placeholder title alt aria-label data-confirm].freeze

      def hardcoded?(repo_path, item)
        path = File.join(repo_path, item)
        return false unless File.exist?(path)

        content = File.read(path, encoding: 'utf-8')
        return false if content.empty?

        if item.end_with?('.html.erb')
          has_hardcoded_erb?(content)
        elsif item.end_with?('.rb')
          has_hardcoded_rb?(content)
        elsif item.end_with?('.html.haml')
          has_hardcoded_haml?(content)
        else
          false
        end
      rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
        false
      end

      def has_hardcoded_erb?(content)
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

      def has_hardcoded_rb?(content)
        lines = content.lines.reject { |l| l.strip.start_with?('#') }
        text = lines.join
        strings = text.scan(/"([^"]*)"/).flatten + text.scan(/'([^']*)'/).flatten

        strings.any? { |s| s.match?(FRENCH_PATTERN) && (s.match?(ACCENTED) || s.match?(FRENCH_WORDS)) }
      end

      def has_hardcoded_haml?(content)
        lines = content.lines
          .reject { |l| l.strip.start_with?('-') }
          .reject { |l| l.strip.match?(/^=\s/) }
          .reject { |l| l.strip.match?(I18N_CALL) }

        lines.join.match?(FRENCH_PATTERN)
      end

      def french_text?(text)
        cleaned = text.strip
        return false if cleaned.empty?

        cleaned.match?(FRENCH_PATTERN)
      end
    end
  end
end
