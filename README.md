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
⚡ **Performance Optimized** - Efficient serialization with intelligent deduplication  
🛡️ **Authorization Ready** - Built-in scoping support for security  
📋 **JSON:API Compliant** - Full specification compliance with sorting, includes, and meta  
🚨 **Robust Error Handling** - Smart inheritance-aware error handling with full customization options

## Installation

Add JPie to your Rails application:

```bash
bundle add jpie
```

## Quick Start - Default Implementation

JPie works out of the box with minimal configuration. Here's a complete example of the default implementation:

### 1. Create Your Model

```ruby
class User < ActiveRecord::Base
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
end
```

### 2. Create Your Resource

```ruby
class UserResource < JPie::Resource
  attributes :name, :email
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

That's it! You now have a fully functional JSON:API compliant server.

## Generators

JPie includes a resource generator for quickly creating new resource classes with proper JSON:API structure.

### Basic Usage

The generator uses semantic field definitions that explicitly categorize each field by its JSON:API purpose:

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
# frozen_string_literal: true

class UserResource < JPie::Resource
  attributes :name, :email

  meta_attributes :created_at, :updated_at

  has_many :comments
  has_one :author
end
```

### Semantic Field Syntax

The generator uses a semantic approach focused on JSON:API concepts rather than database types:

| Syntax | Purpose | Example |
|--------|---------|---------|
| `attribute:field` | Regular JSON:API attribute | `attribute:name` |
| `meta:field` | JSON:API meta attribute | `meta:created_at` |
| `has_many:resource` | JSON:API relationship | `has_many:posts` |
| `has_one:resource` | JSON:API relationship | `has_one:profile` |
| `relationship:type:resource` | Explicit relationship | `relationship:has_many:posts` |

### Advanced Examples

##### Comprehensive Resource

```bash
rails generate jpie:resource Article \
  attribute:title \
  attribute:content \
  meta:published_at \
  meta:created_at \
  meta:updated_at \
  has_one:author \
  has_many:comments \
  has_many:tags \
  --model=Post
```

**Generated file:**
```ruby
# frozen_string_literal: true

class ArticleResource < JPie::Resource
  model Post

  attributes :title, :content

  meta_attributes :published_at, :created_at, :updated_at

  has_one :author
  has_many :comments
  has_many :tags
end
```

##### Empty Resource Template

```bash
rails generate jpie:resource User
```

**Generated file:**
```ruby
# frozen_string_literal: true

class UserResource < JPie::Resource
  # Define your attributes here:
  # attributes :name, :email, :title

  # Define your meta attributes here:
  # meta_attributes :created_at, :updated_at

  # Define your relationships here:
  # has_many :posts
  # has_one :user
end
```

### Legacy Syntax Support

The generator maintains backward compatibility with the Rails-style `field:type` syntax, but ignores the type portion:

```bash
# Legacy syntax (still works, types ignored)
rails generate jpie:resource User name:string email:string created_at:datetime
```

This generates the same output as the semantic syntax, with automatic detection of meta attributes based on common field names.

### Generator Options

| Option | Type | Description | Example |
|--------|------|-------------|---------|
| `--model=NAME` | String | Specify model class (overrides inference) | `--model=Person` |
| `--skip-model` | Boolean | Skip explicit model declaration | `--skip-model` |

### Automatic Features

- **Model Inference**: Automatically infers model class from resource name
- **Resource Inference**: Automatically infers related resource classes for relationships
- **Meta Detection**: Auto-detects common meta attributes (`created_at`, `updated_at`, etc.)
- **Clean Output**: Generates well-structured, commented resource files

### Best Practices

1. **Use semantic syntax** for clarity and JSON:API-appropriate thinking
2. **Be explicit about categorization** when the intent might be unclear
3. **Let JPie handle inference** for standard naming conventions
4. **Use `--model` only when necessary** for non-standard model mappings

## Modern DSL Examples

JPie provides a clean, modern DSL that follows Rails conventions:

### Resource Definition

```ruby
class UserResource < JPie::Resource
  # Attributes (multiple syntaxes supported)
  attributes :name, :email, :created_at
  attribute :full_name
  
  # Meta attributes
  meta :account_status, :last_login
  # or: meta_attributes :account_status, :last_login
  
  # Includes for related data (used with ?include= parameter)
  has_many :posts
  has_one :profile
  
  # Custom sorting
  sortable :popularity do |query, direction|
    query.order(likes_count: direction)
  end
  # or: sortable_by :popularity do |query, direction|
  
  # Custom attribute methods
  private
  
  def full_name
    "#{object.first_name} #{object.last_name}"
  end
  
  def account_status
    object.active? ? 'active' : 'inactive'
  end
end
```

### Controller Definition

```ruby
class UsersController < ApplicationController
  include JPie::Controller
  
  # Explicit resource (optional - auto-inferred by default)
  resource UserResource
  # or: jsonapi_resource UserResource
  
  # Override methods as needed
  def index
    users = current_user.admin? ? User.all : User.active
    render_jsonapi(users)
  end
  
  def create
    attributes = deserialize_params
    user = model_class.new(attributes)
    user.created_by = current_user
    user.save!
    
    render_jsonapi(user, status: :created)
  end
end
```

## Suported JSON:API features

### Sorting
All defined attributes are automatically sortable:

```http
GET /users?sort=name
HTTP/1.1 200 OK
Content-Type: application/vnd.api+json
{
  "data": [
    {
      "id": "1",
      "type": "users", 
      "attributes": {
        "name": "Alice Anderson",
        "email": "alice@example.com"
      }
    },
    {
      "id": "2", 
      "type": "users",
      "attributes": {
        "name": "Bob Brown",
        "email": "bob@example.com"
      }
    },
    {
      "id": "3",
      "type": "users", 
      "attributes": {
        "name": "Carol Clark",
        "email": "carol@example.com"
      }
    }
  ]
}
```

Or by name in reverse order by name:

```http
GET /users?sort=-name
HTTP/1.1 200 OK
Content-Type: application/vnd.api+json
{
  "data": [
    {
      "id": "3",
      "type": "users",
      "attributes": {
        "name": "Carol Clark", 
        "email": "carol@example.com"
      }
    },
    {
      "id": "2",
      "type": "users",
      "attributes": {
        "name": "Bob Brown",
        "email": "bob@example.com"
      }
    },
    {
      "id": "1",
      "type": "users",
      "attributes": {
        "name": "Alice Anderson",
        "email": "alice@example.com"
      }
    }
  ]
}
```

### Includes

JPie supports including related resources using the `?include=` parameter. Related resources are returned in the `included` section of the JSON:API response:

```http
GET /posts/1?include=author
HTTP/1.1 200 OK
Content-Type: application/vnd.api+json
{
  "data": {
    "id": "1",
    "type": "posts",
    "attributes": {
      "title": "My First Post",
      "content": "This is the content of my first post."
    }
  },
  "included": [
    {
      "id": "5",
      "type": "users",
      "attributes": {
        "name": "John Doe",
        "email": "john@example.com"
      }
    }
  ]
}
```

Multiple includes and nested includes are also supported:

```http
GET /posts?include=author,comments,comments.author
```

## Error Handling

JPie provides robust error handling that works correctly with Rails' inheritance and concern systems while allowing full customization.

### Default Error Handling

JPie automatically handles common errors and renders them in JSON:API format:

| Error Type | HTTP Status | Description |
|------------|-------------|-------------|
| `JPie::Errors::Error` | Varies | Base JPie errors with custom status |
| `ActiveRecord::RecordNotFound` | 404 | Missing records |
| `ActiveRecord::RecordInvalid` | 422 | Validation failures |

**Example error response:**

```json
{
  "errors": [
    {
      "status": "404",
      "title": "Not Found", 
      "detail": "Couldn't find User with 'id'=999"
    }
  ]
}
```

### Understanding Rails rescue_from Inheritance Issues

Rails evaluates `rescue_from` handlers in **reverse order** (last-defined-first), which can cause issues with gems that provide default error handling. JPie solves this with smart handler detection that only sets up handlers if they don't already exist.

### Customization Options

#### Option 1: Override Specific Handlers

Define your handlers **before** including JPie to ensure they take precedence:

```ruby
class ApplicationController < ActionController::Base
  # Define your handlers first
  rescue_from ActiveRecord::RecordNotFound, with: :my_not_found_handler
  
  include JPie::Controller
  # JPie will detect existing handler and won't override it
  
  private
  
  def my_not_found_handler(error)
    render json: { 
      error: "Custom not found message",
      detail: error.message 
    }, status: :not_found
  end
end
```

#### Option 2: Extend JPie Handlers

Override JPie's error handling methods while keeping the rescue_from setup:

```ruby
class ApplicationController < ActionController::Base
  include JPie::Controller
  
  private
  
  def render_jpie_not_found_error(error)
    # Add custom logging
    Rails.logger.error "Record not found: #{error.message}"
    
    # Call the original method or implement your own
    super
  end
  
  def render_jpie_validation_error(error)
    # Add error tracking
    ErrorTracker.notify(error)
    
    # Custom validation error format
    errors = error.record.errors.map do |field, message|
      {
        status: "422",
        title: "Validation Error",
        detail: "#{field.humanize} #{message}",
        source: { pointer: "/data/attributes/#{field}" }
      }
    end
    
    render json: { errors: errors }, 
           status: :unprocessable_entity,
           content_type: 'application/vnd.api+json'
  end
end
```

#### Option 3: Disable All JPie Error Handlers

For complete control over error handling:

```ruby
class ApplicationController < ActionController::Base
  include JPie::Controller
  
  disable_jpie_error_handlers
  
  # Define your own handlers
  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  
  private
  
  def handle_standard_error(error)
    # Your custom error handling
  end
  
  def handle_not_found(error)
    # Your custom not found handling
  end
end
```

#### Option 4: Selective Handler Enabling

Disable all handlers and selectively enable only what you need:

```ruby
class ApplicationController < ActionController::Base
  include JPie::Controller
  
  disable_jpie_error_handlers
  
  # Only enable specific handlers you want
  enable_jpie_error_handler(JPie::Errors::Error)
  # ActiveRecord errors will not be handled by JPie
  
  # Handle ActiveRecord errors yourself
  rescue_from ActiveRecord::RecordNotFound, with: :my_not_found_handler
end
```

### Custom JPie Errors

Create custom errors by inheriting from JPie::Errors::Error:

```ruby
# Define custom errors
class CustomBusinessError < JPie::Errors::Error
  def initialize(detail: 'Business logic error')
    super(status: 422, title: 'Business Error', detail: detail)
  end
end

class RateLimitError < JPie::Errors::Error
  def initialize
    super(status: 429, title: 'Rate Limit Exceeded', detail: 'Too many requests')
  end
end

# Use in your controllers
class UsersController < ApplicationController
  include JPie::Controller
  
  def create
    raise RateLimitError if rate_limit_exceeded?
    
    user = User.new(user_params)
    unless user.valid_business_rules?
      raise CustomBusinessError.new(detail: 'User violates business rules')
    end
    
    # ... rest of create logic
  end
end
```

### Error Handler Method Names

JPie prefixes its error handler methods with `jpie_` to avoid conflicts:

- `render_jpie_error` - Main JPie error handler
- `render_jpie_not_found_error` - ActiveRecord not found errors
- `render_jpie_validation_error` - ActiveRecord validation errors

For backward compatibility, the old method names are aliased:
- `render_jsonapi_error` → `render_jpie_error`
- `render_not_found_error` → `render_jpie_not_found_error`
- `render_validation_error` → `render_jpie_validation_error`

### Best Practices

1. **Define custom handlers before including JPie** to ensure precedence
2. **Use JPie error classes** for consistency with JSON:API format
3. **Log errors appropriately** and integrate with error monitoring services
4. **Test error handling** to ensure proper JSON:API format responses

## JSON:API Compliance Validation

JPie automatically validates JSON:API compliance for requests, includes, and sort parameters, providing clear error messages when validation fails.

### Automatic Validation

JPie performs validation automatically in CRUD actions:

- **Request structure validation** for POST/PATCH/PUT operations
- **Include parameter validation** for all read operations  
- **Sort parameter validation** for index operations

### Request Structure Validation

JPie validates that JSON:API requests follow the specification:

```ruby
# Valid JSON:API request
{
  "data": {
    "type": "users",
    "attributes": {
      "name": "John Doe",
      "email": "john@example.com"
    }
  }
}

# Invalid - missing required fields will raise InvalidJsonApiRequestError
{
  "name": "John Doe"  # Missing "data" wrapper and "type"
}
```

**Validation includes:**
- Content-Type header must be `application/vnd.api+json` for write operations
- Request must have top-level `data` member
- Resource objects must have `type` member
- Resource objects must have `id` member for updates
- Valid JSON structure

### Include Parameter Validation

JPie validates that include parameters match supported relationships:

```ruby
class UserResource < JPie::Resource
  has_many :posts
  has_one :profile
  
  # Override to customize supported includes
  def self.supported_includes
    ['posts', 'profile', 'posts.comments']  # Supports nested includes
  end
end

# Valid requests
GET /users?include=posts
GET /users?include=posts,profile  
GET /users?include=posts.comments

# Invalid - raises UnsupportedIncludeError  
GET /users?include=invalid_relationship
```

**Default behavior:** All defined relationships (`has_many`, `has_one`) are supported by default.

### Sort Parameter Validation

JPie validates that sort fields are supported by the resource:

```ruby
class UserResource < JPie::Resource
  attributes :name, :email
  sortable :popularity
  
  # Override to customize supported sort fields
  def self.supported_sort_fields
    ['name', 'email', 'popularity', 'created_at']
  end
end

# Valid requests
GET /users?sort=name
GET /users?sort=-email,name  # Descending email, ascending name
GET /users?sort=popularity

# Invalid - raises UnsupportedSortFieldError
GET /users?sort=invalid_field
```

**Default behavior:** All attributes, sortable fields, and timestamp columns are supported by default.

### Error Responses

Validation errors return proper JSON:API error responses:

```json
{
  "errors": [
    {
      "status": "400",
      "title": "Unsupported Include",
      "detail": "Unsupported include 'comments'. Supported includes: posts, profile"
    }
  ]
}
```

### Customizing Validation

#### Custom Supported Includes

```ruby
class PostResource < JPie::Resource
  has_many :comments
  has_one :author
  
  # Customize supported includes with nested relationships
  def self.supported_includes
    {
      'author' => {},
      'comments' => {
        'author' => {}  # Support comments.author
      }
    }
  end
end
```

#### Custom Supported Sort Fields

```ruby
class PostResource < JPie::Resource
  attributes :title, :content
  
  # Restrict sorting to specific fields only
  def self.supported_sort_fields
    ['title', 'created_at']  # Only allow sorting by title and created_at
  end
end
```

#### Disabling Validation

For special cases where you need to disable validation:

```ruby
class CustomController < ApplicationController
  include JPie::Controller
  
  # Override automatic methods to skip validation
  def index
    # Skip validation calls
    resources = resource_class.scope(context)
    render_jsonapi(resources)
  end
  
  private
  
  # Or override validation methods to customize behavior
  def validate_include_params
    # Custom include validation logic
    # or call super for default behavior
  end
end
```

### Validation Error Types

JPie provides specific error classes for different validation scenarios:

| Error Class | HTTP Status | Description |
|-------------|-------------|-------------|
| `InvalidJsonApiRequestError` | 400 | Invalid request structure or format |
| `UnsupportedIncludeError` | 400 | Include parameter not supported |
| `UnsupportedSortFieldError` | 400 | Sort field not supported |
| `InvalidSortParameterError` | 400 | Invalid sort field format |
| `InvalidIncludeParameterError` | 400 | Invalid include parameter format |

All validation errors can be customized using the same error handling patterns described in the Error Handling section.

## Customization and Overrides

Once you have the basic implementation working, you can customize JPie's behavior as needed:

### Resource Class Inference Override

JPie automatically infers the resource class from your controller name, but you can override this:

```ruby
# Automatic inference (default behavior)
class UsersController < ApplicationController
  include JPie::Controller
  # Automatically uses UserResource
end

# Explicit resource specification (override)
class UsersController < ApplicationController
  include JPie::Controller
  resource UserResource  # Use a different resource class (modern syntax)
  # or: jsonapi_resource UserResource  # (backward compatible syntax)
end
```

### Model Specification Override

JPie automatically infers the model from your resource class name, but you can override this:

```ruby
# Automatic inference (default behavior)
class UserResource < JPie::Resource
  attributes :name, :email
  # Automatically uses User model
end

# Explicit model specification (override)
class UserResource < JPie::Resource
  model CustomUser  # Use a different model class
  attributes :name, :email
end
```

### Controller Method Overrides

You can override any of the automatic CRUD methods:

```ruby
class UsersController < ApplicationController
  include JPie::Controller
  
  # Override index to add filtering
  def index
    users = User.where(active: true)
    render_jsonapi(users)
  end
  
  # Override create to add custom logic
  def create
    attributes = deserialize_params
    user = model_class.new(attributes)
    user.created_by = current_user
    user.save!
    
    render_jsonapi(user, status: :created)
  end
  
  # show, update, destroy still use the automatic implementations
end
```

### Custom Attributes

Add computed or transformed attributes to your resources using either blocks or method overrides:

#### Using Blocks (Original Approach)

```ruby
class UserResource < JPie::Resource
  attribute :display_name do
    "#{object.first_name} #{object.last_name}"
  end

  attribute :admin_notes do
    if context[:current_user]&.admin?
      object.admin_notes
    else
      nil
    end
  end
end
```

#### Using Method Overrides (New Approach)

You can now define custom methods directly on your resource class instead of using blocks:

```ruby
class UserResource < JPie::Resource
  attributes :name, :email
  attribute :full_name
  attribute :display_name
  meta_attribute :user_stats

  private

  def full_name
    "#{object.first_name} #{object.last_name}"
  end

  def display_name
    if context[:admin]
      "#{full_name} [ADMIN VIEW] - #{object.email}"
    else
      full_name
    end
  end

  def user_stats
    {
      name_length: object.name.length,
      email_domain: object.email.split('@').last,
      account_status: object.active? ? 'active' : 'inactive'
    }
  end
end
```

**Key Benefits of Method Overrides:**
- **Cleaner syntax** - No need for blocks
- **Better IDE support** - Full method definitions with proper syntax highlighting
- **Easier testing** - Methods can be tested individually
- **Private methods supported** - Use private methods for internal logic
- **Access to object and context** - Full access to `object` and `context` like blocks

**Method Precedence:**
1. **Blocks** (highest priority) - `attribute :name do ... end`
2. **Options blocks** - `attribute :name, block: proc { ... }`
3. **Custom methods** - `def name; ...; end`
4. **Model attributes** (lowest priority) - Direct model attribute lookup

### Meta attributes

JPie supports adding meta data to your JSON:API resources in two ways: using the `meta_attributes` macro or by defining a custom `meta` method.

#### Using meta_attributes Macro

It's easy to add meta attributes:

```ruby
class UserResource < JPie::Resource
  meta_attributes :created_at, :updated_at
  meta_attributes :last_login_at
end
```

#### Using Custom meta Method

For more complex meta data, you can define a `meta` method that returns a hash:

```ruby
class UserResource < JPie::Resource
  attributes :name, :email
  meta_attributes :created_at, :updated_at

  def meta
    super.merge(
      full_name: "#{object.first_name} #{object.last_name}",
      user_role: context[:current_user]&.role || 'guest',
      account_status: object.active? ? 'active' : 'inactive',
      last_seen: object.last_login_at&.iso8601
    )
  end
end
```

The `meta` method has access to:
- `super` - returns the hash from `meta_attributes` 
- `object` - the underlying model instance
- `context` - any context passed during resource initialization

**Example JSON:API Response with Custom Meta:**

```json
{
  "data": {
    "id": "1",
    "type": "users",
    "attributes": {
      "name": "John Doe",
      "email": "john@example.com"
    },
    "meta": {
      "created_at": "2024-01-01T12:00:00Z",
      "updated_at": "2024-01-15T14:30:00Z",
      "full_name": "John Doe",
      "user_role": "admin",
      "account_status": "active",
      "last_seen": "2024-01-15T14:00:00Z"
    }
  }
}
```

#### Meta Method Inheritance

Meta methods work seamlessly with inheritance:

```ruby
class BaseResource < JPie::Resource
  meta_attributes :created_at, :updated_at

  def meta
    super.merge(
      resource_version: '1.0',
      timestamp: Time.current.iso8601
    )
  end
end

class UserResource < BaseResource
  attributes :name, :email
  meta_attributes :last_login_at

  def meta
    super.merge(
      user_specific_data: calculate_user_metrics
    )
  end

  private

  def calculate_user_metrics
    {
      post_count: object.posts.count,
      comment_count: object.comments.count
    }
  end
end
```

### Custom Sorting

Override the default sorting behavior with custom logic:

```ruby
class PostResource < JPie::Resource
  attributes :title, :content
  
  sortable_by :popularity do |query, direction|
    if direction == :asc
      query.order(:likes_count, :comments_count)
    else
      query.order(likes_count: :desc, comments_count: :desc)
    end
  end
end
```

### Polymorphic Associations

JPie supports polymorphic associations for includes. Here's a complete example with comments that can belong to multiple types of commentable resources:

#### Models with Polymorphic Associations

```ruby
# Comment model with belongs_to polymorphic association
class Comment < ActiveRecord::Base
  belongs_to :commentable, polymorphic: true
  belongs_to :author, class_name: 'User'
  
  validates :content, presence: true
end

# Post model with has_many polymorphic association
class Post < ActiveRecord::Base
  has_many :comments, as: :commentable, dependent: :destroy
  belongs_to :author, class_name: 'User'
  
  validates :title, :content, presence: true
end

# Article model with has_many polymorphic association  
class Article < ActiveRecord::Base
  has_many :comments, as: :commentable, dependent: :destroy
  belongs_to :author, class_name: 'User'
  
  validates :title, :body, presence: true
end
```

#### Resources for Polymorphic Associations

```ruby
# Comment resource
class CommentResource < JPie::Resource
  attributes :content, :created_at
  
  # Define methods for includes
  has_many :comments  # For including nested comments
  has_one :author     # For including the comment author
  
  private
  
  def commentable
    object.commentable
  end
  
  def author
    object.author
  end
end

# Post resource  
class PostResource < JPie::Resource
  attributes :title, :content, :published_at
  
  # Define methods for includes
  has_many :comments
  has_one :author
  
  private
  
  def comments
    object.comments
  end
  
  def author
    object.author
  end
end

# Article resource
class ArticleResource < JPie::Resource
  attributes :title, :body, :published_at
  
  # Define methods for includes
  has_many :comments
  has_one :author
  
  private
  
  def comments
    object.comments
  end
  
  def author
    object.author
  end
end
```

#### Controllers for Polymorphic Resources

```ruby
class CommentsController < ApplicationController
  include JPie::Controller
  
  # Override create to handle polymorphic assignment
  def create
    attributes = deserialize_params
    commentable = find_commentable
    
    comment = commentable.comments.build(attributes)
    comment.author = current_user
    comment.save!
    
    render_jsonapi(comment, status: :created)
  end
  
  private
  
  def find_commentable
    # Extract commentable info from request path or parameters
    if params[:post_id]
      Post.find(params[:post_id])
    elsif params[:article_id]
      Article.find(params[:article_id])
    else
      raise ArgumentError, "Commentable not specified"
    end
  end
end

class PostsController < ApplicationController
  include JPie::Controller
  # Uses default CRUD operations with polymorphic comments included
end

class ArticlesController < ApplicationController
  include JPie::Controller
  # Uses default CRUD operations with polymorphic comments included
end
```

#### Routes for Polymorphic Resources

```ruby
Rails.application.routes.draw do
  resources :posts do
    resources :comments, only: [:index, :create]
  end
  
  resources :articles do
    resources :comments, only: [:index, :create]
  end
  
  resources :comments, only: [:show, :update, :destroy]
end
```

#### Example JSON:API Responses

**GET /posts/1?include=comments,comments.author**

```json
{
  "data": {
    "id": "1",
    "type": "posts",
    "attributes": {
      "title": "My First Post",
      "content": "This is the content of my first post.",
      "published_at": "2024-01-15T10:30:00Z"
    }
  },
  "included": [
    {
      "id": "1",
      "type": "comments",
      "attributes": {
        "content": "Great post!",
        "created_at": "2024-01-15T11:00:00Z"
      }
    },
    {
      "id": "2", 
      "type": "comments",
      "attributes": {
        "content": "Thanks for sharing!",
        "created_at": "2024-01-15T12:00:00Z"
      }
    },
    {
      "id": "5",
      "type": "users",
      "attributes": {
        "name": "John Doe",
        "email": "john@example.com"
      }
    },
    {
      "id": "6",
      "type": "users",
      "attributes": {
        "name": "Jane Smith",
        "email": "jane@example.com"
      }
    }
  ]
}
```

### Single Table Inheritance (STI)

JPie provides comprehensive support for Rails Single Table Inheritance (STI) models. STI allows multiple models to share a single database table with a "type" column to differentiate between them.

#### STI Models

```ruby
# Base model
class Vehicle < ActiveRecord::Base
  validates :name, presence: true
  validates :brand, presence: true
  validates :year, presence: true
end

# STI subclasses
class Car < Vehicle
  validates :engine_size, presence: true
end

class Truck < Vehicle
  validates :cargo_capacity, presence: true
end
```

#### STI Resources

JPie automatically handles STI type inference and resource inheritance:

```ruby
# Base resource
class VehicleResource < JPie::Resource
  attributes :name, :brand, :year
  meta_attributes :created_at, :updated_at
end

# STI resources inherit from base resource
class CarResource < VehicleResource
  attributes :engine_size  # Car-specific attribute
end

class TruckResource < VehicleResource
  attributes :cargo_capacity  # Truck-specific attribute
end
```

#### STI Type Inference

JPie automatically infers the correct JSON:API type from the STI model class:

```ruby
car = Car.create!(name: 'Civic', brand: 'Honda', year: 2020, engine_size: 1500)
car_resource = CarResource.new(car)

car_resource.type  # => "cars" (automatically inferred from Car model)
```

#### STI Serialization

Each STI model serializes with its specific type and attributes:

```ruby
# Car serialization
car_serializer = JPie::Serializer.new(CarResource)
result = car_serializer.serialize(car)

# Result:
{
  "data": {
    "id": "1",
    "type": "cars",  # STI type
    "attributes": {
      "name": "Civic",
      "brand": "Honda", 
      "year": 2020,
      "engine_size": 1500  # Car-specific attribute
    }
  }
}

# Truck serialization  
truck_serializer = JPie::Serializer.new(TruckResource)
result = truck_serializer.serialize(truck)

# Result:
{
  "data": {
    "id": "2", 
    "type": "trucks",  # STI type
    "attributes": {
      "name": "F-150",
      "brand": "Ford",
      "year": 2021,
      "cargo_capacity": 1000  # Truck-specific attribute
    }
  }
}
```

#### STI Controllers

Controllers work seamlessly with STI models:

```ruby
class CarsController < ApplicationController
  include JPie::Controller
  # Automatically uses CarResource and Car model
end

class TrucksController < ApplicationController
  include JPie::Controller  
  # Automatically uses TruckResource and Truck model
end

class VehiclesController < ApplicationController
  include JPie::Controller
  # Uses VehicleResource and returns all vehicles (cars, trucks, etc.)
end
```

#### STI Scoping

Each STI resource automatically scopes to its specific type:

```ruby
CarResource.scope      # Returns only Car records
TruckResource.scope    # Returns only Truck records  
VehicleResource.scope  # Returns all Vehicle records (including STI subclasses)
```

#### Complete STI Example

Here's a complete example showing STI in action with HTTP requests and responses:

**1. Database Setup**

```ruby
# Migration
class CreateVehicles < ActiveRecord::Migration[7.0]
  def change
    create_table :vehicles do |t|
      t.string :type, null: false  # STI discriminator column
      t.string :name, null: false
      t.string :brand, null: false
      t.integer :year, null: false
      t.integer :engine_size       # Car-specific
      t.integer :cargo_capacity    # Truck-specific
      t.timestamps
    end
    
    add_index :vehicles, :type
  end
end
```

**2. Models**

```ruby
class Vehicle < ApplicationRecord
  validates :name, :brand, :year, presence: true
end

class Car < Vehicle
  validates :engine_size, presence: true
end

class Truck < Vehicle  
  validates :cargo_capacity, presence: true
end
```

**3. Resources**

```ruby
class VehicleResource < JPie::Resource
  attributes :name, :brand, :year
  meta_attributes :created_at, :updated_at
end

class CarResource < VehicleResource
  attributes :engine_size
end

class TruckResource < VehicleResource
  attributes :cargo_capacity
end
```

**4. Controllers**

```ruby
class VehiclesController < ApplicationController
  include JPie::Controller
  # Returns all vehicles (cars, trucks, etc.)
end

class CarsController < ApplicationController
  include JPie::Controller
  # Returns only cars with car-specific attributes
end

class TrucksController < ApplicationController
  include JPie::Controller
  # Returns only trucks with truck-specific attributes
end
```

**5. Routes**

```ruby
Rails.application.routes.draw do
  resources :vehicles, only: [:index, :show]
  resources :cars
  resources :trucks
end
```

**6. Example HTTP Requests and Responses**

**GET /cars/1**
```json
{
  "data": {
    "id": "1",
    "type": "cars",
    "attributes": {
      "name": "Model 3",
      "brand": "Tesla", 
      "year": 2023,
      "engine_size": 0
    },
    "meta": {
      "created_at": "2024-01-15T10:00:00Z",
      "updated_at": "2024-01-15T10:00:00Z"
    }
  }
}
```

**GET /trucks/2**
```json
{
  "data": {
    "id": "2", 
    "type": "trucks",
    "attributes": {
      "name": "F-150",
      "brand": "Ford",
      "year": 2023,
      "cargo_capacity": 1200
    },
    "meta": {
      "created_at": "2024-01-15T11:00:00Z",
      "updated_at": "2024-01-15T11:00:00Z"
    }
  }
}
```

**GET /vehicles (Mixed STI Collection)**
```json
{
  "data": [
    {
      "id": "1",
      "type": "cars",
      "attributes": {
        "name": "Model 3",
        "brand": "Tesla",
        "year": 2023,
        "engine_size": 0
      }
    },
    {
      "id": "2",
      "type": "trucks", 
      "attributes": {
        "name": "F-150",
        "brand": "Ford",
        "year": 2023,
        "cargo_capacity": 1200
      }
    }
  ]
}
```

**7. Creating STI Records**

**POST /cars**
```json
{
  "data": {
    "type": "cars",
    "attributes": {
      "name": "Model Y",
      "brand": "Tesla",
      "year": 2024,
      "engine_size": 0
    }
  }
}
```

#### Custom STI Types

You can override the automatic type inference if needed:

```ruby
class CarResource < VehicleResource
  type 'automobiles'  # Custom type instead of 'cars'
  attributes :engine_size
end
```

### Authorization and Scoping

Override the default scope method to add authorization:

```ruby
class PostResource < JPie::Resource  
  attributes :title, :content
  
  def self.scope(context = {})
    current_user = context[:current_user]
    return model.none unless current_user
    Pundit.policy_scope(current_user, model)
  end
end
```

### Custom Context

Override the context building to pass additional data to resources:

```ruby
class UsersController < ApplicationController
  include JPie::Controller
  
  private
  
  def build_context
    {
      current_user: current_user,
      controller: self,
      action: action_name,
      request_ip: request.remote_ip,
      user_agent: request.user_agent
    }
  end
end
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).