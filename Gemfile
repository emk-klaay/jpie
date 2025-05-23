# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'rake', '~> 13.0'

group :development, :test do
  gem 'brakeman', '~> 6.0'
  gem 'rspec', '~> 3.12'
  gem 'rspec-rails', '~> 7.0'
  gem 'rubocop', '~> 1.50'
  gem 'rubocop-performance', '~> 1.16'
  gem 'rubocop-rails', '~> 2.18'
  gem 'rubocop-rspec', '~> 2.20'
end

group :test do
  gem 'rails', '~> 8.0'
  gem 'simplecov', '~> 0.22.0', require: false
  gem 'sqlite3', '~> 2.1'
  gem 'ostruct', '~> 0.6.0'
end
