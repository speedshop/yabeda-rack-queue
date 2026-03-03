# frozen_string_literal: true

require "test_helper"
require "benchmark/ips"

class MiddlewarePerformanceTest < Minitest::Test
  MINIMUM_IPS = 1_000_000.0

  def test_processes_noop_rack_app_above_one_million_calls_per_second
    response = [200, {"content-type" => "text/plain"}, ["hello world"]].freeze
    app = ->(_env) { response }
    middleware = Yabeda::Rack::Queue::Middleware.new(app)
    env = {}.freeze

    report = Benchmark.ips do |x|
      x.config(time: 1, warmup: 0.5)
      x.report("middleware noop call") { middleware.call(env) }
    end

    observed_ips = report.entries.fetch(0).ips
    assert_operator observed_ips, :>, MINIMUM_IPS
  end
end
