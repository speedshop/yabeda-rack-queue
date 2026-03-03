# frozen_string_literal: true

require "spec_helper"

RSpec.describe "rack_queue metric registration" do
  it "registers rack_queue_duration histogram with required metadata" do
    metric = Yabeda.rack_queue.rack_queue_duration

    expect(metric).to be_a(Yabeda::Histogram)
    expect(metric.group).to eq(:rack_queue)
    expect(metric.unit).to eq(:seconds)
    expect(metric.comment).to eq("Time a request waited in the upstream queue before reaching the application")
    expect(metric.tags).to eq([])
    expect(metric.buckets).to eq(
      [0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10, 30, 60]
    )
  end
end
