# frozen_string_literal: true

require "bundler/setup"
require "yabeda/test_adapter"
require "yabeda/rack/queue"

Yabeda.register_adapter(:test, Yabeda::TestAdapter.instance)
Yabeda.configure! unless Yabeda.configured?

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }

  config.before do
    Yabeda::TestAdapter.instance.reset!
  end
end
