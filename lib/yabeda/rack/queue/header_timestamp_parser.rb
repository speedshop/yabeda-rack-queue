# frozen_string_literal: true

module Yabeda
  module Rack
    module Queue
      class HeaderTimestampParser
        MIN_EPOCH_SECONDS = Time.utc(2000, 1, 1).to_f
        FUTURE_TOLERANCE_SECONDS = 30.0
        NORMALIZATION_DIVISORS = [1_000_000.0, 1_000.0, 1.0].freeze
        NUMBER_PATTERN = /[+-]?(?:\d+(?:\.\d+)?|\.\d+)/
        T_EQUALS_PATTERN = /t\s*=\s*(#{NUMBER_PATTERN.source})/i

        def parse(value, now:)
          first_value = first_header_value(value)
          return nil if first_value.empty?

          token = extract_numeric_token(first_value)
          return nil if token.nil?

          normalize(Float(token), now)
        rescue ArgumentError, TypeError
          nil
        end

        private

        def first_header_value(value)
          value.to_s.split(",", 2).first.to_s.strip
        end

        def extract_numeric_token(value)
          value[T_EQUALS_PATTERN, 1] || value[NUMBER_PATTERN, 0]
        end

        def normalize(raw_timestamp, now)
          max_allowed = now + FUTURE_TOLERANCE_SECONDS

          NORMALIZATION_DIVISORS.each do |divisor|
            candidate = raw_timestamp / divisor
            next if candidate < MIN_EPOCH_SECONDS
            next if candidate > max_allowed

            return candidate
          end

          nil
        end
      end
    end
  end
end
