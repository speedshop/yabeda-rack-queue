# frozen_string_literal: true

require "test_helper"
require "net/http"
require "puma"
require "socket"
require "timeout"

class PumaServerHarness
  attr_reader :port

  def initialize(app)
    @app = app
  end

  def start
    @server = Puma::Server.new(@app, nil, min_threads: 0, max_threads: 4)
    @server.add_tcp_listener("127.0.0.1", 0)
    @port = @server.connected_ports.first
    @server.run(true, thread_name: "puma-e2e")
    wait_until_ready
  end

  def stop
    @server&.stop(true)
  end

  private

  def wait_until_ready
    Timeout.timeout(5) do
      loop do
        socket = TCPSocket.new("127.0.0.1", port)
        socket.close
        break
      rescue Errno::ECONNREFUSED
        sleep 0.01
      end
    end
  end
end

class PumaIntegrationTest < Minitest::Test
  def setup
    super
    rack_app = Yabeda::Rack::Queue::Middleware.new(
      ->(_env) { [200, {"content-type" => "text/plain"}, ["ok"]] }
    )
    @server = PumaServerHarness.new(rack_app)
    @server.start
  end

  def teardown
    @server&.stop
    super
  end

  def test_records_rack_queue_duration_histogram_via_yabeda_on_real_http_request
    requested_queue_time_seconds = 0.12
    request_start_ms = ((Time.now.to_f - requested_queue_time_seconds) * 1_000).to_i
    uri = URI("http://127.0.0.1:#{@server.port}/")
    request = Net::HTTP::Get.new(uri)
    request["X-Request-Start"] = request_start_ms.to_s

    response = Net::HTTP.start(uri.host, uri.port) { |http| http.request(request) }

    assert_equal "200", response.code

    metric = Yabeda.rack_queue.rack_queue_duration
    measured = Yabeda::TestAdapter.instance.histograms.fetch(metric).fetch({})

    assert_kind_of Float, measured
    assert_operator measured, :>=, requested_queue_time_seconds
  end
end
