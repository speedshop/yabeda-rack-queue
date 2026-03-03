# frozen_string_literal: true

require "spec_helper"
require "net/http"
require "puma"
require "socket"
require "timeout"

RSpec.describe "Puma E2E queue time reporting" do
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
          begin
            socket = TCPSocket.new("127.0.0.1", port)
            socket.close
            break
          rescue Errno::ECONNREFUSED
            sleep 0.01
          end
        end
      end
    end
  end

  let(:rack_app) do
    Yabeda::Rack::Queue::Middleware.new(
      ->(_env) { [200, { "content-type" => "text/plain" }, ["ok"]] }
    )
  end
  let(:server) { PumaServerHarness.new(rack_app) }

  before do
    server.start
  rescue Errno::EPERM
    skip "Socket binding is not permitted in this environment"
  end

  after do
    server.stop
  end

  it "records rack_queue_duration histogram via Yabeda on a real HTTP request" do
    request_start_ms = ((Time.now.to_f - 0.12) * 1_000).to_i
    uri = URI("http://127.0.0.1:#{server.port}/")
    request = Net::HTTP::Get.new(uri)
    request["X-Request-Start"] = request_start_ms.to_s

    response = Net::HTTP.start(uri.host, uri.port) { |http| http.request(request) }

    expect(response.code).to eq("200")

    metric = Yabeda.rack_queue.rack_queue_duration
    measured = Yabeda::TestAdapter.instance.histograms.fetch(metric).fetch({})

    expect(measured).to be_a(Float)
    expect(measured).to be >= 0.0
  end
end
