# frozen_string_literal: true

require_relative "lib/yabeda/rack/queue/version"

Gem::Specification.new do |spec|
  spec.name = "yabeda-rack-queue"
  spec.version = Yabeda::Rack::Queue::VERSION
  spec.authors = ["Yabeda Contributors"]
  spec.email = ["maintainers@yabeda.dev"]

  spec.summary = "Yabeda middleware for HTTP request queue duration"
  spec.description = <<~DESCRIPTION
    Rack middleware that measures HTTP request queue duration from upstream
    headers and reports it to Yabeda as a histogram metric.
  DESCRIPTION
  spec.homepage = "https://github.com/yabeda-rb/yabeda-rack-queue"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/yabeda-rb/yabeda-rack-queue/issues",
    "changelog_uri" => "https://github.com/yabeda-rb/yabeda-rack-queue/releases",
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/yabeda-rb/yabeda-rack-queue",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |file|
      file.start_with?(".github/", ".pi/")
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "rack", ">= 2.2", "< 4.0"
  spec.add_dependency "yabeda", ">= 0.14", "< 1.0"

  spec.add_development_dependency "puma", ">= 6", "< 8"
  spec.add_development_dependency "rake", ">= 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
end
