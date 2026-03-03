# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

task :lint do
  sh "bundle exec standardrb"
end

Rake::TestTask.new(:test) do |test|
  test.libs << "test"
  test.pattern = "test/**/*_test.rb"
end

task default: %i[lint test]
