# frozen_string_literal: true

require "test_helper"

class MetricTest < Minitest::Test
  def test_registers_rack_queue_duration_histogram_with_required_metadata
    metric = Yabeda.rack_queue.rack_queue_duration

    assert_instance_of Yabeda::Histogram, metric
    assert_equal :rack_queue, metric.group
    assert_equal :seconds, metric.unit
    assert_equal "Time a request waited in the upstream queue before reaching the application", metric.comment
    assert_equal [], metric.tags
    assert_equal [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30, 60], metric.buckets
  end
end
