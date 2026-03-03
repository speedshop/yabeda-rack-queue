# frozen_string_literal: true

require "bundler/setup"
require "minitest/autorun"
require "yabeda/test_adapter"
require "yabeda/rack/queue"

Yabeda.register_adapter(:test, Yabeda::TestAdapter.instance)
Yabeda.configure! unless Yabeda.configured?

class Minitest::Test
  def setup
    super
    Yabeda::TestAdapter.instance.reset!
  end
end
