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