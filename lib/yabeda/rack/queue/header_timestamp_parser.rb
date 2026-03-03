# frozen_string_literal: true

module Yabeda
  module Rack
    module Queue
      class HeaderTimestampParser
        MIN_EPOCH = Time.utc(2000, 1, 1).to_f
        FUTURE_TOLERANCE = 30.0
        DIVISORS = [1_000_000.0, 1_000.0, 1.0].freeze
        NUMBER_RE = /[+-]?(?:\d+(?:\.\d+)?|\.\d+)/
        T_EQUALS_RE = /t\s*=\s*(#{NUMBER_RE.source})/i

        def parse(value, now:)
          first = value.to_s.split(",", 2).first.to_s.strip
          return if first.empty?

          token = first[T_EQUALS_RE, 1] || first[NUMBER_RE, 0]
          normalize(Float(token), now) if token
        rescue ArgumentError, TypeError
        end

        private

        def normalize(raw, now)
          max = now + FUTURE_TOLERANCE
          divisor = DIVISORS.find { |d| (raw / d).between?(MIN_EPOCH, max) }
          raw / divisor if divisor
        end
      end
    end
  end
end
