# frozen_string_literal: true

require 'simplecov'

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'

  add_group 'Core', 'lib/jpie'
  add_group 'Generators', 'lib/jpie/generators'

  minimum_coverage 80
  minimum_coverage_by_file 60
end

require 'jpie'
require 'ostruct'

# Set up ActiveRecord database
require_relative 'support/database'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed

  # Clean database between tests
  config.before do
    ActiveRecord::Base.connection.tables.each do |table|
      next if table == 'schema_migrations'

      ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
    end
  end
end
