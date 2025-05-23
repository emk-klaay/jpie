# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Automatic CRUD methods in controllers: Controllers now automatically get `index`, `show`, `create`, `update`, and `destroy` methods when including `JPie::Controller` and calling `jsonapi_resource`
- SimpleCov for code coverage tracking and reporting
- Comprehensive Single Table Inheritance (STI) support: Automatic type inference, resource inheritance, and polymorphic serialization for Rails STI models

### Changed
- Controllers are now much simpler - just `include JPie::Controller` and `jsonapi_resource YourResource` provides full CRUD functionality
- CRUD methods can still be overridden for custom behavior

## [0.1.0] - 2024-01-01

### Added
- Initial release with core functionality
- JSON:API compliant serialization and deserialization
- Resource definition with attributes
- Controller integration module
- Rails generator for creating resources
- Comprehensive error handling
- Configuration system for key formats
- Full test suite with RSpec

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