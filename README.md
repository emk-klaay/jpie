# JPie

[![Gem Version](https://badge.fury.io/rb/jpie.svg)](https://badge.fury.io/rb/jpie)
[![Build Status](https://github.com/emilkampp/jpie/workflows/CI/badge.svg)](https://github.com/emilkampp/jpie/actions)

JPie is a modern, lightweight Rails library for developing JSON:API compliant servers. It focuses on clean architecture with strong separation of concerns and extensibility.

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
  jsonapi_resource CustomUserResource  # Use a different resource class
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
    render_jsonapi_resources(users)
  end
  
  # Override create to add custom logic
  def create
    attributes = deserialize_params
    user = User.new(attributes)
    user.created_by = current_user
    user.save!
    
    render_jsonapi_resource(user, status: :created)
  end
  
  # show, update, destroy still use the automatic implementations
end
```

### Custom Attributes

Add computed or transformed attributes to your resources:

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

### Meta attributes

It's easy to add meta attributes:

```ruby
class UserResource < JPie::Resource
  meta_attributes :created_at, :updated_at
  meta_attributes :last_login_at
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

JPie supports polymorphic associations seamlessly. Here's a complete example with comments that can belong to multiple types of commentable resources:

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
# Comment resource with belongs_to polymorphic relationship
class CommentResource < JPie::Resource
  attributes :content, :created_at
  
  # Polymorphic belongs_to relationship
  relationship :commentable do
    # Dynamically determine the resource class based on the commentable type
    case object.commentable_type
    when 'Post'
      PostResource.new(object.commentable, context)
    when 'Article'
      ArticleResource.new(object.commentable, context)
    else
      nil
    end
  end
  
  relationship :author do
    UserResource.new(object.author, context) if object.author
  end
end

# Post resource with has_many polymorphic relationship
class PostResource < JPie::Resource
  attributes :title, :content, :published_at
  
  # Has_many polymorphic relationship
  relationship :comments do
    object.comments.map { |comment| CommentResource.new(comment, context) }
  end
  
  relationship :author do
    UserResource.new(object.author, context) if object.author
  end
end

# Article resource with has_many polymorphic relationship
class ArticleResource < JPie::Resource
  attributes :title, :body, :published_at
  
  # Has_many polymorphic relationship
  relationship :comments do
    object.comments.map { |comment| CommentResource.new(comment, context) }
  end
  
  relationship :author do
    UserResource.new(object.author, context) if object.author
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
    
    render_jsonapi_resource(comment, status: :created)
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
    },
    "relationships": {
      "comments": {
        "data": [
          { "id": "1", "type": "comments" },
          { "id": "2", "type": "comments" }
        ]
      }
    }
  },
  "included": [
    {
      "id": "1",
      "type": "comments",
      "attributes": {
        "content": "Great post!",
        "created_at": "2024-01-15T11:00:00Z"
      },
      "relationships": {
        "commentable": {
          "data": { "id": "1", "type": "posts" }
        },
        "author": {
          "data": { "id": "5", "type": "users" }
        }
      }
    },
    {
      "id": "2", 
      "type": "comments",
      "attributes": {
        "content": "Thanks for sharing!",
        "created_at": "2024-01-15T12:00:00Z"
      },
      "relationships": {
        "commentable": {
          "data": { "id": "1", "type": "posts" }
        },
        "author": {
          "data": { "id": "6", "type": "users" }
        }
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

#### STI in Polymorphic Relationships

JPie's serializer automatically determines the correct resource class for STI models in polymorphic relationships:

```ruby
# If a polymorphic relationship returns STI objects,
# JPie will automatically use the correct resource class
# (CarResource for Car objects, TruckResource for Truck objects, etc.)
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