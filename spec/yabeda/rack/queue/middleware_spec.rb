# frozen_string_literal: true

require "spec_helper"

RSpec.describe Yabeda::Rack::Queue::Middleware do
  let(:response) { [201, {"content-type" => "text/plain"}, ["ok"]] }
  let(:app) { ->(_env) { response } }
  let(:reporter) do
    Class.new do
      attr_reader :values

      def initialize
        @values = []
      end

      def observe(value)
        @values << value
      end
    end.new
  end
  let(:now) { 1_700_000_000.0 }
  let(:clock) { -> { now } }
  let(:logger) do
    Class.new do
      attr_reader :warnings

      def initialize
        @warnings = []
      end

      def warn(message)
        @warnings << message
      end
    end.new
  end
  let(:middleware) { described_class.new(app, reporter: reporter, clock: clock, logger: logger) }

  describe "#call" do
    it "always calls the downstream app and returns the downstream response unchanged" do
      env = {}
      expect(app).to receive(:call).with(env).and_call_original

      result = middleware.call(env)

      expect(result).to equal(response)
    end

    it "does not mutate rack env" do
      env = {"HTTP_X_REQUEST_START" => "t=1699999999.9", "custom.key" => "value"}
      original = env.dup

      middleware.call(env)

      expect(env).to eq(original)
    end

    it "records nothing when neither header is present" do
      middleware.call({})
      expect(reporter.values).to be_empty
    end

    it "uses HTTP_X_REQUEST_START before HTTP_X_QUEUE_START when both are valid" do
      env = {
        "HTTP_X_REQUEST_START" => "t=1699999999.9",
        "HTTP_X_QUEUE_START" => "t=1699999999.8"
      }

      middleware.call(env)

      expect(reporter.values.last).to be_within(1e-4).of(0.1)
    end

    it "falls back to HTTP_X_QUEUE_START when HTTP_X_REQUEST_START is invalid" do
      env = {
        "HTTP_X_REQUEST_START" => "invalid",
        "HTTP_X_QUEUE_START" => "t=1699999999.9"
      }

      middleware.call(env)

      expect(reporter.values.last).to be_within(1e-4).of(0.1)
    end

    it "computes queue time before calling downstream app" do
      sleeping_app = ->(_env) do
        sleep 0.05
        response
      end
      test_middleware = described_class.new(sleeping_app, reporter: reporter, clock: clock, logger: logger)

      test_middleware.call("HTTP_X_REQUEST_START" => "t=1699999999.9")

      expect(reporter.values.last).to be_within(1e-4).of(0.1)
    end

    it "uses Process.clock_gettime(Process::CLOCK_REALTIME) by default" do
      default_clock_middleware = described_class.new(app, reporter: reporter, logger: logger)
      expect(Process).to receive(:clock_gettime).with(Process::CLOCK_REALTIME).and_return(now)

      default_clock_middleware.call("HTTP_X_REQUEST_START" => "t=1699999999.9")
    end

    it "never raises on invalid header values" do
      expect do
        middleware.call("HTTP_X_REQUEST_START" => Object.new, "HTTP_X_QUEUE_START" => "")
      end.not_to raise_error
    end

    it "drops negative queue times and logs warning" do
      middleware.call("HTTP_X_REQUEST_START" => "t=1700000000.1")

      expect(reporter.values).to be_empty
      expect(logger.warnings.join("\n")).to include("Negative rack queue duration")
    end

    it "subtracts puma.request_body_wait milliseconds from queue time" do
      middleware.call(
        "HTTP_X_REQUEST_START" => "t=1699999999.9",
        "puma.request_body_wait" => 40
      )

      expect(reporter.values.last).to be_within(1e-4).of(0.06)
    end

    it "coerces string puma.request_body_wait values" do
      middleware.call(
        "HTTP_X_REQUEST_START" => "t=1699999999.9",
        "puma.request_body_wait" => "40"
      )

      expect(reporter.values.last).to be_within(1e-4).of(0.06)
    end

    it "ignores non-numeric puma.request_body_wait values" do
      middleware.call(
        "HTTP_X_REQUEST_START" => "t=1699999999.9",
        "puma.request_body_wait" => "not-a-number"
      )

      expect(reporter.values.last).to be_within(1e-4).of(0.1)
    end

    it "ignores negative puma.request_body_wait values" do
      middleware.call(
        "HTTP_X_REQUEST_START" => "t=1699999999.9",
        "puma.request_body_wait" => -40
      )

      expect(reporter.values.last).to be_within(1e-4).of(0.1)
    end

    it "clamps to zero after puma.request_body_wait subtraction" do
      middleware.call(
        "HTTP_X_REQUEST_START" => "t=1699999999.9",
        "puma.request_body_wait" => 200
      )

      expect(reporter.values.last).to eq(0.0)
    end
  end
end
