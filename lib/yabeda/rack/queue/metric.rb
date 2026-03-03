# frozen_string_literal: true

require "yabeda"

module Yabeda
  module Rack
    module Queue
      HISTOGRAM_BUCKETS = [
        0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30, 60
      ].freeze

      METRIC_NAME = :rack_queue_duration
      METRIC_GROUP = :rack_queue
      METRIC_UNIT = :seconds
      METRIC_DESCRIPTION = "Time a request waited in the upstream queue before reaching the application"
    end
  end
end

Yabeda.configure do
  group Yabeda::Rack::Queue::METRIC_GROUP do
    histogram Yabeda::Rack::Queue::METRIC_NAME,
              comment: Yabeda::Rack::Queue::METRIC_DESCRIPTION,
              unit: Yabeda::Rack::Queue::METRIC_UNIT,
              buckets: Yabeda::Rack::Queue::HISTOGRAM_BUCKETS
  end
end
