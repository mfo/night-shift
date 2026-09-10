# frozen_string_literal: true

#
# BackendWindow — fenêtre horaire qui bascule le backend par défaut.
#
# Ex: `from: "20:00"` / `to: "04:00"` / `backend: frontier` fait tourner
# les skills sur le harness frontier la nuit, et sur le backend par défaut
# le reste du temps. La fenêtre est [from, to[ et peut franchir minuit.
#
module Nightshift
  module Core
    class BackendWindow < T::Struct
      extend T::Sig

      const :backend, String
      const :from_min, Integer
      const :to_min, Integer

      DAY_MIN = 24 * 60

      # Accepte "20:00" (String) ou 72000 (Integer — YAML sexagésimal si non quoté).
      sig { params(value: T.untyped).returns(Integer) }
      def self.parse_time(value)
        case value
        when Integer
          # YAML 1.1 lit `20:00` non quoté comme 20*3600 secondes.
          abort "nightshift: heure invalide (#{value}) — utilise des guillemets: \"HH:MM\"" unless (value % 60).zero? && value < 86_400
          value / 60
        when String
          m = value.strip.match(/\A(\d{1,2}):(\d{2})\z/)
          abort "nightshift: heure invalide (#{value.inspect}) — format attendu \"HH:MM\"" unless m
          h = m[1].to_i
          min = m[2].to_i
          abort "nightshift: heure hors bornes (#{value.inspect})" if h > 23 || min > 59
          (h * 60) + min
        else
          abort "nightshift: heure invalide (#{value.inspect}) — format attendu \"HH:MM\""
        end
      end

      sig { params(now: Time).returns(T::Boolean) }
      def covers?(now)
        min = (now.hour * 60) + now.min
        wraps? ? (min >= from_min || min < to_min) : (min >= from_min && min < to_min)
      end

      sig { returns(T::Boolean) }
      def wraps? = from_min > to_min

      sig { returns(String) }
      def label = "#{self.class.format_min(from_min)}→#{self.class.format_min(to_min)}"

      sig { params(min: Integer).returns(String) }
      def self.format_min(min) = format('%02d:%02d', min / 60, min % 60)
    end
  end
end
