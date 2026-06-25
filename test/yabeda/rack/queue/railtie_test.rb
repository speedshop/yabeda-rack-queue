# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

class RailtieTest < Minitest::Test
  def test_loads_yabeda_railtie_when_rails_appears_after_yabeda
    script = <<~RUBY
      require "bundler/setup"
      require "yabeda"

      module Rails
        class Railtie
          def self.config
            @config ||= Config.new
          end

          class Config
            def after_initialize
            end
          end
        end
      end

      require "yabeda/rack/queue"

      abort "Yabeda::Rails::Railtie was not loaded" unless defined?(Yabeda::Rails::Railtie)
    RUBY

    stdout, stderr, status = Open3.capture3("bundle", "exec", RbConfig.ruby, "-Ilib", "-e", script)

    assert status.success?, [stdout, stderr].join("\n")
  end
end
