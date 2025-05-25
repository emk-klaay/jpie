# JPie Spec Organization

This directory contains the test suite for JPie, organized by feature area for better maintainability and clarity.

## Directory Structure

### 📁 `core/`
Core JPie functionality and basic components:
- `resource_spec.rb` - JPie::Resource class functionality
- `controller_spec.rb` - JPie::Controller class functionality  
- `serializer_spec.rb` - JPie::Serializer class functionality
- `deserializer_spec.rb` - JPie::Deserializer class functionality
- `configuration_spec.rb` - JPie configuration system
- `errors_spec.rb` - JPie error handling
- `comment_resource_spec.rb` - CommentResource example tests
- `post_resource_spec.rb` - PostResource example tests
- `comments_controller_spec.rb` - CommentsController example tests
- `posts_controller_spec.rb` - PostsController example tests

### 📁 `validation/`
JSON:API validation and error handling:
- `json_api_validation_spec.rb` - JSON:API request/response validation
- `error_handling_inheritance_spec.rb` - Error handling inheritance patterns

### 📁 `crud/`
CRUD operations and automatic behaviors:
- `automatic_crud_spec.rb` - Automatic CRUD functionality
- `meta_method_spec.rb` - Meta method support and customization
- `resource_method_override_spec.rb` - Resource method overriding

### 📁 `polymorphic/`
Polymorphic associations and handling:
- `polymorphic_crud_spec.rb` - Polymorphic CRUD operations
- `polymorphic_comprehensive_spec.rb` - Comprehensive polymorphic scenarios
- `polymorphic_tags_spec.rb` - Polymorphic tagging functionality
- `clean_polymorphic_api_spec.rb` - Clean API design for polymorphic relationships
- `multi_polymorphic_includes_spec.rb` - Multiple polymorphic includes

### 📁 `includes/`
Include/relationship functionality:
- `include_spec.rb` - Basic include functionality
- `integration_include_spec.rb` - Include integration tests
- `nested_includes_integration_spec.rb` - Nested includes support

### 📁 `sorting/`
Sorting and filtering features:
- `sorting_integration_spec.rb` - Sorting functionality and validation

### 📁 `sti/`
Single Table Inheritance support:
- `sti_support_spec.rb` - STI model handling and resource inference

### 📁 `associations/`
Association handling and through relationships:
- `through_association_spec.rb` - Through association support

### 📁 `authorization/`
Authorization and scoping:
- `authorization_integration_spec.rb` - Authorization and resource scoping

### 📁 `integration/`
Full integration and complex scenario tests:
- `clean_api_comparison_spec.rb` - Clean API design patterns
- `deep_nesting_evaluation_spec.rb` - Deep nesting scenarios
- `extreme_depth_test_spec.rb` - Extreme depth testing

### 📁 `generators/`
Code generators:
- `resource_generator_spec.rb` - Resource generator functionality

## Running Tests

### Run all tests:
```bash
bundle exec rspec spec/jpie/
```

### Run tests by feature area:
```bash
# Core functionality
bundle exec rspec spec/jpie/core/

# Polymorphic features
bundle exec rspec spec/jpie/polymorphic/

# Include functionality
bundle exec rspec spec/jpie/includes/

# CRUD operations
bundle exec rspec spec/jpie/crud/

# And so on...
```

### Run specific test files:
```bash
bundle exec rspec spec/jpie/core/resource_spec.rb
bundle exec rspec spec/jpie/validation/json_api_validation_spec.rb
```

## Test Coverage

The test suite maintains comprehensive coverage across all JPie features:
- Core resource and controller functionality
- JSON:API compliance and validation
- Polymorphic associations
- Complex includes and relationships
- Authorization and scoping
- STI support
- CRUD operations
- Error handling

## Contributing

When adding new tests:
1. Place them in the appropriate feature directory
2. Follow the existing naming conventions
3. Ensure tests are focused and well-documented
4. Run the full test suite to ensure no regressions 