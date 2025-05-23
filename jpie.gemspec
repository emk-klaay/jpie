# frozen_string_literal: true

require_relative 'lib/jpie/version'

Gem::Specification.new do |spec|
  spec.name = 'jpie'
  spec.version = JPie::VERSION
  spec.authors = ['Emil Kampp']
  spec.email = ['emil@example.com']

  spec.summary = 'A resource-focused Rails library for developing JSON:API compliant servers'
  spec.description = 'JPie provides a framework for developing JSON:API compliant servers with Rails 8+. ' \
                     'It focuses on clean architecture with strong separation of concerns.'
  spec.homepage = 'https://github.com/emilkampp/jpie'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.4.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'activesupport', '>= 8.0.0'
  spec.add_dependency 'rails', '>= 8.0.0'

  # Development dependencies
  spec.add_development_dependency 'brakeman', '~> 6.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rspec-rails', '~> 7.0'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'rubocop-performance', '~> 1.16'
  spec.add_development_dependency 'rubocop-rails', '~> 2.18'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.20'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
