# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.2] - 2025-01-25

### Added
- **Pagination Example**: Comprehensive pagination example demonstrating both simple and JSON:API standard pagination formats
  - Simple pagination parameters (`page`, `per_page`)
  - JSON:API standard pagination format (`page[number]`, `page[size]`)
  - Pagination combined with sorting functionality
  - Edge cases including last page and empty results
  - Complete HTTP request/response examples following project format

### Enhanced
- **Documentation**: Improved example coverage with detailed pagination use cases
- **Developer Experience**: Clear examples for implementing pagination in JPie applications

## [0.4.1] - 2025-01-25

### Fixed
- **Test Suite Stability**: Fixed require statements in spec files that were incorrectly requiring `rails_helper` instead of `spec_helper`
  - Fixed `spec/jpie/automatic_crud_spec.rb`
  - Fixed `spec/jpie/polymorphic_crud_spec.rb` 
  - Fixed `spec/jpie/through_associations_crud_spec.rb`
- **Code Quality**: Addressed RuboCop warnings and improved code style compliance
- **Error Handling**: Improved error message consistency for unsupported sort fields and include parameters

### Enhanced
- **Test Coverage**: Maintained high test coverage (93.39%) with improved test reliability
- **Documentation**: Updated gem publishing workflow and development guidelines

### Technical Details
- All spec files now correctly use `spec_helper` for consistent test environment setup
- Improved gem build process with proper dependency management
- Enhanced RuboCop configuration for better code quality enforcement

## [0.4.0] - 2025-01-25

### Added
- **Semantic Generator Syntax**: Complete rewrite of resource generator with JSON:API-focused field categorization
  - `attribute:field` - Explicit JSON:API attribute definition
  - `meta:field` - Explicit JSON:API meta attribute definition  
  - `has_many:resource` - Shorthand relationship syntax
  - `relationship:type:field` - Explicit relationship syntax
- **Improved Developer Experience**: More intuitive and semantic generator approach focused on JSON:API concepts rather than database types

### Enhanced
- **Generator Logic**: Refactored generator into cleaner, more maintainable methods with proper separation of concerns
- **Backward Compatibility**: Legacy `field:type` syntax fully preserved - existing usage continues to work unchanged
- **Code Quality**: Fixed all RuboCop violations in generator code with improved method structure
- **Test Coverage**: Comprehensive test suite covering semantic syntax, legacy compatibility, and all feature combinations

### Improved
- **Generator Syntax**: Replaced meaningless database types (`name:string`) with semantic JSON:API categorization (`attribute:name`)
- **Documentation**: README completely updated to showcase new semantic approach with comprehensive examples
- **Generator Help**: Updated help text and banners to reflect new semantic syntax

### Technical Details
- Generator automatically categorizes fields based on semantic prefixes
- Auto-detection of common meta attributes (`created_at`, `updated_at`, etc.) preserved
- Relationship inference and resource class detection maintained
- All 373 tests pass with 95.97% coverage maintained

### Migration Guide
- **New syntax (recommended)**: `rails generate jpie:resource User attribute:name meta:created_at has_many:posts`
- **Legacy syntax (still works)**: `rails generate jpie:resource User name:string created_at:datetime --relationships=has_many:posts`
- No breaking changes - existing generators continue to work as before

## [0.3.1] - 2025-01-24

### Fixed
- **Gemspec Metadata**: Updated homepage URL to correct GitHub repository (https://github.com/emk-klaay/jpie)
- **Documentation Links**: Fixed source code and changelog URLs in gem metadata

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