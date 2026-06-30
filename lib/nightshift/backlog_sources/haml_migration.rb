# frozen_string_literal: true

module Nightshift
  module BacklogSources
    class HamlMigration < Base
      sig { override.returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def scan
        glob('app/views/**/*.html.haml') + glob('app/components/**/*.html.haml')
      end

      sig { override.params(item: T::Hash[Symbol, T.untyped]).returns(Integer) }
      def prioritize(item)
        prioritize_by_view_path(item[:item])
      end
    end
  end
end
