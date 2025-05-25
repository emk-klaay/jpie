# JPie Examples

This directory contains comprehensive examples demonstrating the various features and capabilities of the JPie gem. Each example file is self-contained and includes models, resources, controllers, and example API requests/responses.

## 📋 Available Examples

### 🚀 [Basic Usage](basic_usage.rb)
**What it demonstrates:**
- Fundamental JPie setup and configuration
- Simple resource definitions with attributes and meta attributes
- Basic controller setup with automatic CRUD operations
- Standard JSON:API request/response patterns

**Key learning points:**
- How to create your first JPie resource
- Automatic model and controller inference
- Basic sorting and includes functionality

---

### 🔗 [Through Associations](through_associations.rb)
**What it demonstrates:**
- Rails `:through` associations with JPie resources
- Many-to-many relationships through join tables
- Clean API design that hides join table complexity
- Advanced through associations with custom names

**Key learning points:**
- Using `has_many :drivers, through: :car_drivers`
- How JPie handles complex associations transparently
- Nested includes with through associations

---

### 🎨 [Custom Attributes and Meta](custom_attributes_and_meta.rb)
**What it demonstrates:**
- Custom computed attributes using method overrides
- Block-based attribute definitions (legacy approach)
- Complex meta data with custom `meta` method override
- Context-aware attributes and conditional visibility

**Key learning points:**
- Modern method-based vs legacy block-based approaches
- Using `object` and `context` in custom methods
- Authorization-aware attribute rendering

---

### 🔄 [Polymorphic Associations](polymorphic_associations.rb)
**What it demonstrates:**
- Polymorphic associations (comments belonging to posts, articles, videos)
- Dynamic resource behavior based on polymorphic type
- Handling polymorphic relationships in controllers
- Complex nested includes with polymorphic data

**Key learning points:**
- Setting up polymorphic models and resources
- Creating flexible API endpoints for polymorphic data
- Dynamic attribute behavior based on associated type

---

### 🏗️ [Single Table Inheritance](single_table_inheritance.rb)
**What it demonstrates:**
- STI models (Vehicle → Car, Truck, Motorcycle)
- Inheritance in both models and resources
- Type-specific attributes and computed values
- Automatic STI type inference in JSON:API responses

**Key learning points:**
- How JPie handles STI automatically
- Creating type-specific resources with shared base functionality
- Dynamic attributes based on STI type

---

### 📊 [Custom Sorting](custom_sorting.rb)
**What it demonstrates:**
- Custom sorting logic with complex algorithms
- Multi-criteria sorting (popularity, engagement, trending)
- Database-specific sorting (joins, subqueries, window functions)
- Controller integration with custom sort endpoints

**Key learning points:**
- Using `sortable` and `sortable_by` macros
- Complex SQL sorting with Arel
- Performance considerations for custom sorts

---

### ⚠️ [Error Handling](error_handling.rb)
**What it demonstrates:**
- Custom JPie error classes and business logic errors
- Comprehensive error handling strategies
- Authorization and validation error patterns
- Controller-level error management

**Key learning points:**
- Creating custom error types
- Overriding JPie's default error handlers
- Providing detailed, user-friendly error responses

## 🎯 How to Use These Examples

### 1. **Study the Code Structure**
Each example follows this pattern:
- **Models** - ActiveRecord models with validations and associations
- **Resources** - JPie resource classes with attributes and relationships
- **Controllers** - Controllers that use JPie for API endpoints
- **Routes** - Rails routing configuration
- **Examples** - Sample API requests and responses

### 2. **Copy and Adapt**
These examples are designed to be copied and adapted for your own use cases:
```ruby
# Copy the pattern you need
class YourResource < JPie::Resource
  # Adapt the attributes and relationships
  attributes :your_attributes
  has_many :your_relationships
end
```

### 3. **Mix and Match Features**
Combine concepts from different examples:
- Use custom attributes from one example
- Add error handling from another
- Implement sorting from a third

### 4. **Start Simple, Then Extend**
1. Begin with **Basic Usage** to understand fundamentals
2. Add **Custom Attributes** as your needs grow
3. Implement **Error Handling** for production readiness
4. Use advanced features like **Polymorphic Associations** when needed

## 🔧 Testing the Examples

You can test these examples in a Rails console or by creating a sample application:

```ruby
# In Rails console
user = User.create!(name: 'John Doe', email: 'john@example.com')
resource = UserResource.new(user)
serializer = JPie::Serializer.new(UserResource)
result = serializer.serialize(user)
puts JSON.pretty_generate(result)
```

## 📚 Related Documentation

- **Main README**: `../README.md` - Complete feature overview
- **API Documentation**: Generated from code comments
- **JSON:API Specification**: [jsonapi.org](https://jsonapi.org/)

## 💡 Contributing Examples

Have a use case that's not covered? Consider contributing an example:

1. Follow the established pattern (models → resources → controllers → examples)
2. Include comprehensive comments explaining the concepts
3. Provide realistic sample data and API responses
4. Test your example thoroughly

Each example should be educational and demonstrate best practices for using JPie in real-world applications. 