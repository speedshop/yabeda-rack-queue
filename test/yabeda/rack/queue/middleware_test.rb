# frozen_string_literal: true

require "test_helper"

class CapturingReporter
  attr_reader :values

  def initialize
    @values = []
  end

  def observe(value)
    @values << value
  end
end

class CapturingLogger
  attr_reader :warnings

  def initialize
    @warnings = []
  end

  def warn(message)
    @warnings << message
  end
end

class AppSpy
  attr_reader :called_count, :last_env

  def initialize(response)
    @response = response
    @called_count = 0
  end

  def call(env)
    @called_count += 1
    @last_env = env
    @response
  end
end

class MiddlewareTest < Minitest::Test
  def setup
    super
    @response = [201, {"content-type" => "text/plain"}, ["ok"]]
    @app = AppSpy.new(@response)
    @reporter = CapturingReporter.new
    @now = 1_700_000_000.0
    @clock = -> { @now }
    @logger = CapturingLogger.new
    @middleware = Yabeda::Rack::Queue::Middleware.new(
      @app,
      reporter: @reporter,
      clock: @clock,
      logger: @logger
    )
  end

  def test_always_calls_downstream_app_and_returns_response_unchanged
    env = {}

    result = @middleware.call(env)

    assert_same @response, result
    assert_equal 1, @app.called_count
    assert_same env, @app.last_env
  end

  def test_does_not_mutate_rack_env
    env = {"HTTP_X_REQUEST_START" => "t=1699999999.9", "custom.key" => "value"}
    original = env.dup

    @middleware.call(env)

    assert_equal original, env
  end

  def test_records_nothing_when_neither_header_is_present
    @middleware.call({})

    assert_empty @reporter.values
  end

  def test_uses_x_request_start_before_x_queue_start_when_both_are_valid
    env = {
      "HTTP_X_REQUEST_START" => "t=1699999999.9",
      "HTTP_X_QUEUE_START" => "t=1699999999.8"
    }

    @middleware.call(env)

    assert_in_delta 0.1, @reporter.values.last, 1e-4
  end

  def test_falls_back_to_x_queue_start_when_x_request_start_is_invalid
    env = {
      "HTTP_X_REQUEST_START" => "invalid",
      "HTTP_X_QUEUE_START" => "t=1699999999.9"
    }

    @middleware.call(env)

    assert_in_delta 0.1, @reporter.values.last, 1e-4
  end

  def test_computes_queue_time_before_calling_downstream_app
    sleeping_app = lambda do |_env|
      sleep 0.05
      @response
    end
    test_middleware = Yabeda::Rack::Queue::Middleware.new(
      sleeping_app,
      reporter: @reporter,
      clock: @clock,
      logger: @logger
    )

    test_middleware.call("HTTP_X_REQUEST_START" => "t=1699999999.9")

    assert_in_delta 0.1, @reporter.values.last, 1e-4
  end

  def test_uses_process_clock_gettime_realtime_by_default
    middleware = Yabeda::Rack::Queue::Middleware.new(@app, reporter: @reporter, logger: @logger)
    observed_clock_ids = []
    clock_gettime_stub = lambda do |clock_id|
      observed_clock_ids << clock_id
      @now
    end

    Process.stub(:clock_gettime, clock_gettime_stub) do
      middleware.call("HTTP_X_REQUEST_START" => "t=1699999999.9")
    end

    refute_empty @reporter.values
    assert_equal [Process::CLOCK_REALTIME], observed_clock_ids
  end

  def test_never_raises_on_invalid_header_values
    @middleware.call("HTTP_X_REQUEST_START" => Object.new, "HTTP_X_QUEUE_START" => "")
    assert_equal 1, @app.called_count
    assert_empty @reporter.values
  end

  def test_drops_negative_queue_times_and_logs_warning
    @middleware.call("HTTP_X_REQUEST_START" => "t=1700000000.1")

    assert_equal 1, @app.called_count
    assert_empty @reporter.values
    assert_includes @logger.warnings.join("\n"), "Negative rack queue duration"
  end

  def test_subtracts_puma_request_body_wait_milliseconds_from_queue_time
    @middleware.call(
      "HTTP_X_REQUEST_START" => "t=1699999999.9",
      "puma.request_body_wait" => 40
    )

    assert_in_delta 0.06, @reporter.values.last, 1e-4
  end

  def test_coerces_string_puma_request_body_wait_values
    @middleware.call(
      "HTTP_X_REQUEST_START" => "t=1699999999.9",
      "puma.request_body_wait" => "40"
    )

    assert_in_delta 0.06, @reporter.values.last, 1e-4
  end

  def test_ignores_non_numeric_puma_request_body_wait_values
    @middleware.call(
      "HTTP_X_REQUEST_START" => "t=1699999999.9",
      "puma.request_body_wait" => "not-a-number"
    )

    assert_in_delta 0.1, @reporter.values.last, 1e-4
  end

  def test_ignores_negative_puma_request_body_wait_values
    @middleware.call(
      "HTTP_X_REQUEST_START" => "t=1699999999.9",
      "puma.request_body_wait" => -40
    )

    assert_in_delta 0.1, @reporter.values.last, 1e-4
  end

  def test_clamps_to_zero_after_puma_request_body_wait_subtraction
    @middleware.call(
      "HTTP_X_REQUEST_START" => "t=1699999999.9",
      "puma.request_body_wait" => 200
    )

    assert_equal 0.0, @reporter.values.last
  end
end
