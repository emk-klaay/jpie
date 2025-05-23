# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

desc 'Run Brakeman security scanner'
task brakeman: :environment do
  require 'brakeman'
  Brakeman.run app_path: '.', print_report: true, exit_on_warn: true
end

desc 'Run all checks (RSpec, RuboCop, Brakeman)'
task check: %i[spec rubocop brakeman]

task default: :check
