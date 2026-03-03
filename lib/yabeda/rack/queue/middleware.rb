# frozen_string_literal: true

module Yabeda
  module Rack
    module Queue
      class Middleware
        HEADER_KEYS = %w[HTTP_X_REQUEST_START HTTP_X_QUEUE_START].freeze
        REQUEST_BODY_WAIT_KEY = "puma.request_body_wait"

        class StderrLogger
          def warn(message)
            Kernel.warn(message)
          end
        end

        class YabedaReporter
          def observe(value)
            Yabeda.rack_queue.rack_queue_duration.measure({}, value)
          end
        end

        def initialize(app, reporter: YabedaReporter.new, parser: HeaderTimestampParser.new, logger: nil, clock: nil)
          @app = app
          @reporter = reporter
          @parser = parser
          @logger = logger || StderrLogger.new
          @clock = clock || -> { Process.clock_gettime(Process::CLOCK_REALTIME) }
        end

        def call(env)
          now = @clock.call
          request_start = request_start_timestamp(env, now)

          report_queue_time(env, now, request_start) if request_start

          @app.call(env)
        end

        private

        def request_start_timestamp(env, now)
          HEADER_KEYS.each do |header_key|
            header_value = env[header_key]
            next if header_value.nil?

            parsed = @parser.parse(header_value, now: now)
            return parsed if parsed
          end

          nil
        end

        def report_queue_time(env, now, request_start)
          queue_time = now - request_start
          if queue_time.negative?
            @logger.warn("Negative rack queue duration (#{queue_time}) observed; dropping measurement")
            return
          end

          body_wait = parse_request_body_wait(env[REQUEST_BODY_WAIT_KEY])
          queue_time -= body_wait if body_wait
          queue_time = 0.0 if queue_time.negative?

          @reporter.observe(queue_time)
        end

        def parse_request_body_wait(value)
          return nil if value.nil?

          milliseconds = Float(value)
          return nil if milliseconds.negative?

          milliseconds / 1_000.0
        rescue ArgumentError, TypeError
          nil
        end
      end
    end
  end
end
