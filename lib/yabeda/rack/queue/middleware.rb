# frozen_string_literal: true

module Yabeda
  module Rack
    module Queue
      class Middleware
        class StderrLogger
          def warn(message) = Kernel.warn(message)
        end

        class YabedaReporter
          def observe(value) = Yabeda.rack_queue.rack_queue_duration.measure({}, value)
        end

        def initialize(app, reporter: YabedaReporter.new, logger: nil, clock: nil)
          @app = app
          @reporter = reporter
          @parser = HeaderTimestampParser.new
          @logger = logger || StderrLogger.new
          @clock = clock || -> { Process.clock_gettime(Process::CLOCK_REALTIME) }
        end

        def call(env)
          measure_queue_time(env) if env["HTTP_X_REQUEST_START"] || env["HTTP_X_QUEUE_START"]
          @app.call(env)
        end

        private

        def measure_queue_time(env)
          now = @clock.call
          start = @parser.parse(env["HTTP_X_REQUEST_START"], now: now) ||
            @parser.parse(env["HTTP_X_QUEUE_START"], now: now)
          report_queue_time(env, now, start) if start
        end

        def report_queue_time(env, now, request_start)
          queue_time = now - request_start
          return @logger.warn("Negative rack queue duration (#{queue_time}); dropping") if queue_time.negative?

          body_wait = parse_body_wait(env["puma.request_body_wait"])
          @reporter.observe([queue_time - (body_wait || 0), 0.0].max)
        end

        def parse_body_wait(value)
          ms = Float(value)
          ms / 1_000.0 unless ms.negative?
        rescue ArgumentError, TypeError
        end
      end
    end
  end
end
