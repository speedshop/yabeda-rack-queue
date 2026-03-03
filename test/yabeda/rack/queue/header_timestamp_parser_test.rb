# frozen_string_literal: true

require "test_helper"

class HeaderTimestampParserTest < Minitest::Test
  def setup
    super
    @parser = Yabeda::Rack::Queue::HeaderTimestampParser.new
    @now = 1_700_000_000.0
  end

  def test_accepts_known_valid_values_from_truth_table
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
      actual = @parser.parse(header_value, now: @now)
      assert_in_delta expected, actual, 1e-9, header_value
    end
  end

  def test_rejects_known_invalid_values_from_truth_table
    ["invalid", "t=", "t=0", "t=915148800", "t=1700000035"].each do |header_value|
      assert_nil @parser.parse(header_value, now: @now), header_value
    end
  end

  def test_prefers_t_equals_token_over_plain_token_when_both_are_present
    value = @parser.parse("1512370000 t=1512379167.574", now: @now)
    assert_in_delta 1_512_379_167.574, value, 1e-9
  end

  def test_returns_nil_for_non_string_values_that_cannot_be_parsed
    assert_nil @parser.parse(nil, now: @now)
    assert_nil @parser.parse(Object.new, now: @now)
  end

  def test_rejects_values_more_than_30_seconds_in_the_future
    header_value = "t=#{@now + 30.001}"
    assert_nil @parser.parse(header_value, now: @now)
  end

  def test_accepts_values_exactly_30_seconds_in_the_future
    header_value = "t=#{@now + 30.0}"
    assert_in_delta @now + 30.0, @parser.parse(header_value, now: @now), 1e-9
  end

  def test_uses_only_first_comma_separated_value
    assert_nil @parser.parse("invalid, t=1512379167.574", now: @now)
  end
end
