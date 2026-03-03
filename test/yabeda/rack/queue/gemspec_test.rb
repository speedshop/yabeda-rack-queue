# frozen_string_literal: true

require "test_helper"

class GemspecTest < Minitest::Test
  def test_does_not_declare_rack_runtime_dependency
    gemspec_path = File.expand_path("../../../../yabeda-rack-queue.gemspec", __dir__)
    spec = Gem::Specification.load(gemspec_path)

    refute_nil spec
    assert_nil spec.runtime_dependencies.find { |dependency| dependency.name == "rack" }
  end
end
