# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-01-01

### Added
- Initial release of JPie gem
- Basic JSON:API resource serialization and deserialization
- Support for attributes only (no relationships yet)
- Rails 8+ integration via Controller module
- Comprehensive error handling with JSON:API compliant error responses
- Configurable key formatting (dasherized, underscored, camelized)
- Rails generator for creating resource classes
- RSpec test suite with comprehensive coverage
- RuboCop and Brakeman integration for code quality
- Ruby 3.4+ and Rails 8+ compatibility

### Features
- `JPie::Resource` - Base class for defining API resources
- `JPie::Serializer` - Converts Ruby objects to JSON:API format
- `JPie::Deserializer` - Converts JSON:API format to Ruby hashes
- `JPie::Controller` - Rails integration module
- `JPie::Configuration` - Gem-wide configuration management
- `JPie::Errors` - JSON:API compliant error classes
- Rails generator: `rails generate jpie:resource`

### Dependencies
- Ruby >= 3.4.0
- Rails >= 8.0.0
- ActiveSupport >= 8.0.0 