# frozen_string_literal: true

require "yabeda"

Yabeda.configure do
  group :rack_queue do
    histogram :rack_queue_duration,
      comment: "Time a request waited in the upstream queue before reaching the application",
      unit: :seconds,
      buckets: [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30, 60]
  end
end
