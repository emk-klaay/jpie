# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2025-01-24

### Added
- **Modern DSL Aliases**: Introduced concise aliases following Rails conventions
  - `render_jsonapi` - Single method for rendering both resources and collections
  - `resource` - Concise alias for `jsonapi_resource` in controllers
  - `meta` and `metas` - Short aliases for `meta_attribute` and `meta_attributes`
  - `sortable` - Concise alias for `sortable_by` in resources
- **Method Override Support**: Custom attribute methods can now be defined directly on resource classes
  - Support for both public and private method definitions
  - Access to `object` and `context` within custom methods
  - Method precedence: blocks → options blocks → custom methods → model attributes
- **Enhanced Documentation**: Comprehensive README updates with Key Features section and modern DSL examples

### Enhanced
- **Controller DSL**: Simplified rendering with intelligent `render_jsonapi` method that handles both single resources and collections automatically
- **Resource DSL**: More intuitive and concise method names aligned with modern Rails patterns
- **Backward Compatibility**: All original method names preserved via aliases - no breaking changes
- **Code Quality**: 100% test coverage maintained with 363 passing tests and full RuboCop compliance

### Improved
- **Developer Experience**: Cleaner, more intuitive API that follows Rails conventions
- **IDE Support**: Better support for custom attribute methods with proper method definitions
- **Testing**: Easier testing of individual custom methods vs block-based approaches
- **Performance**: Method-based attributes avoid block overhead for simple transformations

### Technical Details
- Custom methods support both public and private visibility
- Intelligent method detection prevents overriding existing custom implementations
- All render methods consolidated into single polymorphic `render_jsonapi` method
- Full backward compatibility ensures seamless upgrades

## [0.2.0] - 2025-01-24

### Added
- **Single Table Inheritance (STI) Support**: Comprehensive support for Rails STI models with automatic type inference, resource inheritance, and polymorphic serialization
- **Custom Meta Method**: Resources can now define a `meta` method to provide dynamic meta data alongside the existing `meta_attributes` macro, with access to `object`, `context`, and ability to call `super`
- **Enhanced Test Coverage**: Added comprehensive test suites for STI and meta method functionality with 95.13% line coverage
- **RuboCop Configuration**: Improved RuboCop configuration for test files, reducing offenses from 247 to 0 while maintaining code quality

### Enhanced
- **STI Models**: Automatic JSON:API type inference from STI model classes (e.g., `Car` model → `"cars"` type)
- **STI Resources**: Seamless resource inheritance matching model inheritance patterns  
- **STI Serialization**: Each STI model serializes with correct type and specific attributes
- **STI Controllers**: Automatic scoping to specific STI types while supporting polymorphic queries
- **Meta Method Features**: Dynamic meta data generation with context access and inheritance support
- **Documentation**: Comprehensive README updates with STI examples and meta method usage

### Improved
- **Test Suite**: 343 tests covering all functionality including complex STI scenarios
- **Code Quality**: Zero RuboCop offenses with reasonable configuration for comprehensive test suites
- **Error Handling**: Proper validation for meta method return types with helpful error messages

### Technical Details
- STI models automatically infer correct resource classes for polymorphic serialization
- Meta methods can access `object`, `context`, and call `super` for attribute merging
- RuboCop configuration optimized for integration tests without compromising production code standards
- Comprehensive test coverage for edge cases and complex scenarios

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