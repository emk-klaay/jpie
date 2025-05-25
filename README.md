# JPie

[![Gem Version](https://badge.fury.io/rb/jpie.svg)](https://badge.fury.io/rb/jpie)
[![Build Status](https://github.com/emilkampp/jpie/workflows/CI/badge.svg)](https://github.com/emilkampp/jpie/actions)

JPie is a modern, lightweight Rails library for developing JSON:API compliant servers. It focuses on clean architecture with strong separation of concerns and extensibility.

## Key Features

✨ **Modern Rails DSL** - Clean, intuitive syntax following Rails conventions  
🔧 **Method Overrides** - Define custom attribute methods directly on resource classes  
🎯 **Smart Inference** - Automatic model and resource class detection  
⚡ **Powerful Generators** - Scaffold resources with relationships, meta attributes, and automatic inference  
📊 **Polymorphic Support** - Full support for complex polymorphic associations  
🔄 **STI Ready** - Single Table Inheritance works out of the box  
🔗 **Through Associations** - Full support for Rails `:through` associations  
⚡ **Performance Optimized** - Efficient serialization with intelligent deduplication  
🛡️ **Authorization Ready** - Built-in scoping support for security  
📋 **JSON:API Compliant** - Full specification compliance with sorting, includes, and meta  
🚨 **Robust Error Handling** - Smart inheritance-aware error handling with full customization options

## Installation

Add JPie to your Rails application:

```bash
bundle add jpie
```

## Quick Start

JPie works out of the box with minimal configuration:

### 1. Create Your Model

```ruby
class User < ActiveRecord::Base
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  
  has_many :posts, dependent: :destroy
  has_one :profile, dependent: :destroy
end
```

### 2. Create Your Resource

```ruby
class UserResource < JPie::Resource
  attributes :name, :email
  meta_attributes :created_at, :updated_at
  
  has_many :posts
  has_one :profile
end
```

### 3. Create Your Controller

```ruby
class UsersController < ApplicationController
  include JPie::Controller
end
```

### 4. Set Up Routes

```ruby
Rails.application.routes.draw do
  resources :users
end
```

That's it! You now have a fully functional JSON:API compliant server with automatic CRUD operations, sorting, includes, and validation.

## 📚 Comprehensive Examples

JPie includes a complete set of examples demonstrating all features:

- **[🚀 Basic Usage](https://github.com/emilkampp/jpie/blob/main/examples/basic_usage.rb)** - Fundamental setup and configuration
- **[🔗 Through Associations](https://github.com/emilkampp/jpie/blob/main/examples/through_associations.rb)** - Many-to-many relationships with `:through`
- **[🎨 Custom Attributes & Meta](https://github.com/emilkampp/jpie/blob/main/examples/custom_attributes_and_meta.rb)** - Custom computed attributes and meta data
- **[🔄 Polymorphic Associations](https://github.com/emilkampp/jpie/blob/main/examples/polymorphic_associations.rb)** - Complex polymorphic relationships
- **[🏗️ Single Table Inheritance](https://github.com/emilkampp/jpie/blob/main/examples/single_table_inheritance.rb)** - STI models and resources
- **[📊 Custom Sorting](https://github.com/emilkampp/jpie/blob/main/examples/custom_sorting.rb)** - Advanced sorting with complex algorithms
- **[⚠️ Error Handling](https://github.com/emilkampp/jpie/blob/main/examples/error_handling.rb)** - Comprehensive error handling strategies

Each example is self-contained with models, resources, controllers, and sample API requests/responses. **[📋 View all examples →](https://github.com/emilkampp/jpie/blob/main/examples/)**

## Generators

JPie includes a resource generator for quickly creating new resource classes:

### Basic Usage

```bash
# Generate a basic resource with semantic syntax
rails generate jpie:resource User attribute:name attribute:email meta:created_at

# Shorthand for relationships
rails generate jpie:resource Post attribute:title attribute:content has_many:comments has_one:author

# Mix explicit categorization with auto-detection
rails generate jpie:resource User attribute:name email created_at updated_at
```

**Generated file:**
```ruby
class UserResource < JPie::Resource
  attributes :name, :email
  meta_attributes :created_at, :updated_at
  
  has_many :comments
  has_one :author
end
```

### Semantic Field Syntax

| Syntax | Purpose | Example |
|--------|---------|---------|
| `attribute:field` | Regular JSON:API attribute | `attribute:name` |
| `meta:field` | JSON:API meta attribute | `meta:created_at` |
| `has_many:resource` | JSON:API relationship | `has_many:posts` |
| `has_one:resource` | JSON:API relationship | `has_one:profile` |

### Generator Options

| Option | Description | Example |
|--------|-------------|---------|
| `--model=NAME` | Specify model class | `--model=Person` |
| `--skip-model` | Skip explicit model declaration | `--skip-model` |

### Modern DSL

```ruby
class UserResource < JPie::Resource
  # Multiple attributes at once
  attributes :name, :email, :created_at
  
  # Meta attributes (for additional data)
  meta :account_status, :last_login
  
  # Relationships for includes
  has_many :posts
  has_one :profile
  
  # Custom sorting
  sortable :popularity do |query, direction|
    query.order(likes_count: direction)
  end
  
  # Custom attribute methods (modern approach)
  private
  
  def account_status
    object.active? ? 'active' : 'inactive'
  end
end
```

See the examples folder for more examples of how to use the DSL to solve various serialization/deserialization scenarios.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/emilkampp/jpie.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).