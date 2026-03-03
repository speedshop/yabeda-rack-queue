# frozen_string_literal: true

require "spec_helper"

RSpec.describe Yabeda::Rack::Queue::HeaderTimestampParser do
  subject(:parser) { described_class.new }

  let(:now) { 1_700_000_000.0 }

  describe "#parse" do
    it "accepts known valid values from the truth table" do
      expectations = {
        "t=1512379167.574" => 1_512_379_167.574,
        "1512379167.574" => 1_512_379_167.574,
        "t=1512379167574" => 1_512_379_167.574,
        "1512379167574" => 1_512_379_167.574,
        "t=1570633834463123" => 1_570_633_834.463123,
        "1570633834463123" => 1_570_633_834.463123,
        "t=1512379167" => 1_512_379_167.0,
        "1512379167" => 1_512_379_167.0,
        "  t=1512379167.574  " => 1_512_379_167.574,
        "t=1512379167.574, t=1512379168.000" => 1_512_379_167.574
      }

      expectations.each do |header_value, expected|
        actual = parser.parse(header_value, now: now)
        expect(actual).to be_within(1e-9).of(expected)
      end
    end

    it "rejects known invalid values from the truth table" do
      [
        "invalid",
        "t=",
        "t=0",
        "t=915148800",
        "t=1700000035"
      ].each do |header_value|
        expect(parser.parse(header_value, now: now)).to be_nil
      end
    end

    it "prefers t= token over plain token when both are present" do
      value = parser.parse("1512370000 t=1512379167.574", now: now)
      expect(value).to be_within(1e-9).of(1_512_379_167.574)
    end

    it "returns nil for non-string values that cannot be parsed" do
      expect(parser.parse(nil, now: now)).to be_nil
      expect(parser.parse(Object.new, now: now)).to be_nil
    end

    it "rejects values more than 30 seconds in the future" do
      header_value = "t=#{now + 30.001}"
      expect(parser.parse(header_value, now: now)).to be_nil
    end
  end
end
