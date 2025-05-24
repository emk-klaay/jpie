# JPie

[![Gem Version](https://badge.fury.io/rb/jpie.svg)](https://badge.fury.io/rb/jpie)
[![Build Status](https://github.com/emilkampp/jpie/workflows/CI/badge.svg)](https://github.com/emilkampp/jpie/actions)

JPie is a modern, lightweight Rails library for developing JSON:API compliant servers. It focuses on clean architecture with strong separation of concerns and extensibility.

## Key Features

✨ **Modern Rails DSL** - Clean, intuitive syntax following Rails conventions  
🔧 **Method Overrides** - Define custom attribute methods directly on resource classes  
🎯 **Smart Inference** - Automatic model and resource class detection  
📊 **Polymorphic Support** - Full support for complex polymorphic associations  
🔄 **STI Ready** - Single Table Inheritance works out of the box  
⚡ **Performance Optimized** - Efficient serialization with intelligent deduplication  
🛡️ **Authorization Ready** - Built-in scoping support for security  
📋 **JSON:API Compliant** - Full specification compliance with sorting, includes, and meta  

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