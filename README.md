# JPie

[![Gem Version](https://badge.fury.io/rb/jpie.svg)](https://badge.fury.io/rb/jpie)
[![Build Status](https://github.com/emilkampp/jpie/workflows/CI/badge.svg)](https://github.com/emilkampp/jpie/actions)

JPie is a modern, lightweight Rails library for developing JSON:API compliant servers. It focuses on clean architecture with strong separation of concerns and extensibility.

## Features

- **JSON:API Compliant**: Follows the [JSON:API specification](https://jsonapi.org/)
- **Rails 8+ Support**: Built specifically for modern Rails applications
- **Ruby 3.4+ Compatible**: Takes advantage of the latest Ruby features
- **Clean Architecture**: Strong separation of concerns with extensible design
- **Type Safety**: Proper input validation and error handling
- **Configurable**: Support for different key formats (dasherized, underscored, camelized)

## Requirements

- Ruby 3.4+
- Rails 8.0+

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'jpie'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install jpie
```

## Usage

### Automatic Resource Inference

JPie automatically infers the resource class from your controller name, eliminating the need for explicit configuration in most cases:

```ruby
# app/controllers/users_controller.rb
class UsersController < ApplicationController
  include JPie::Controller
  
  # That's it! JPie automatically infers UserResource
  # and provides all CRUD methods
end

# app/controllers/posts_controller.rb  
class PostsController < ApplicationController
  include JPie::Controller
  
  # Automatically infers PostResource
end
```

The inference follows these conventions:
- `UsersController` → `UserResource`
- `PostsController` → `PostResource`
- `Api::V1::UsersController` → `UserResource` (ignores namespaces)

### Explicit Resource Configuration

You can still explicitly specify a resource class when needed:

```ruby
class UsersController < ApplicationController
  include JPie::Controller
  jsonapi_resource CustomUserResource
end
```

### Resource Classes

Define your resource classes to specify which attributes should be serialized:

```ruby
class UserResource < JPie::Resource
  model User
  
  attribute :id
  attribute :name
  attribute :email
end
```

### Model Classes

Your model classes work with any ORM or plain Ruby objects:

```ruby
class User < ActiveRecord::Base
  # ActiveRecord model
end

# Or with plain Ruby objects
class User
  attr_accessor :id, :name, :email
  
  def initialize(id:, name:, email:)
    @id = id
    @name = name
    @email = email
  end
end
```

## Quick Start

### 1. Create a Resource

Generate a resource for your model:

```bash
rails generate jpie:resource User name email created_at
```

Or create one manually:

```ruby
# app/resources/user_resource.rb
class UserResource < JPie::Resource
  model User
  
  attributes :name, :email, :created_at
end
```

### 2. Update Your Controller

```ruby
class UsersController < ApplicationController
  include JPie::Controller
  
  jsonapi_resource UserResource
  
  # That's it! The following methods are automatically provided:
  # - index: GET /users
  # - show: GET /users/:id  
  # - create: POST /users
  # - update: PATCH/PUT /users/:id
  # - destroy: DELETE /users/:id
end
```

You can override any of these methods for custom behavior:

```ruby
class UsersController < ApplicationController
  include JPie::Controller
  
  jsonapi_resource UserResource
  
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
  
  # All other methods (show, update, destroy) use the defaults
end
```

### 3. Example JSON:API Response

```json
{
  "data": {
    "id": "1",
    "type": "users",
    "attributes": {
      "name": "John Doe",
      "email": "john@example.com",
      "created-at": "2024-01-01T12:00:00Z"
    }
  }
}
```

## Configuration

Configure JPie in an initializer:

```ruby
# config/initializers/jpie.rb
JPie.configure do |config|
  config.json_key_format = :dasherized  # :dasherized, :underscored, :camelized
  config.default_page_size = 20
  config.maximum_page_size = 1000
end
```

## Advanced Usage

### Custom Attributes

```ruby
class UserResource < JPie::Resource
  model User
  
  attributes :name, :email
  
  # Custom attribute with transformation
  attribute :display_name do
    "#{object.first_name} #{object.last_name}"
  end
  
  # Attribute from a different method
  attribute :full_email, attr: :email_with_domain
end
```

### Error Handling

JPie provides comprehensive error handling:

```ruby
# Custom error handling in your controller
def create
  attributes = deserialize_params
  user = User.new(attributes)
  
  unless user.save
    raise JPie::Errors::ValidationError.new(
      detail: user.errors.full_messages.join(', ')
    )
  end
  
  render_jsonapi_resource(user, status: :created)
rescue JPie::Errors::ValidationError => e
  render json: { errors: [e.to_hash] }, status: :unprocessable_entity
end
```

### Context and Authorization

```ruby
class UserResource < JPie::Resource
  model User
  
  attributes :name, :email
  
  # Conditional attribute based on context
  attribute :admin_notes do
    if context[:current_user]&.admin?
      object.admin_notes
    else
      nil
    end
  end
end

# In your controller
def build_context
  {
    current_user: current_user,
    controller: self,
    action: action_name
  }
end
```

### Resource Scoping for Authorization

JPie supports authorization through resource scoping. Override the `scope` method in your resource classes to control which records users can access:

```ruby
class PostResource < JPie::Resource
  model Post
  
  attributes :title, :content
  
  # Override scope for authorization
  def self.scope(context = {})
    current_user = context[:current_user]
    return model.none unless current_user
    
    # Admins can see all posts, users can only see their own posts
    if current_user.admin?
      model.all
    else
      model.where(user: current_user)
    end
  end
end
```

This works seamlessly with authorization libraries like Pundit:

```ruby
class PostResource < JPie::Resource
  model Post
  
  attributes :title, :content
  
  def self.scope(context = {})
    current_user = context[:current_user]
    return model.none unless current_user
    
    # Use Pundit policy scopes
    Pundit.policy_scope(current_user, model)
  end
end
```

The controller automatically uses the scoped query for all CRUD operations:

```ruby
class PostsController < ApplicationController
  include JPie::Controller
  jsonapi_resource PostResource
  
  # All these methods automatically use PostResource.scope(context):
  # - index: shows only posts the user can see
  # - show: finds only from posts the user can see  
  # - update: updates only posts the user can modify
  # - destroy: destroys only posts the user can delete
end
```

## Testing

JPie is thoroughly tested with RSpec. Run the test suite:

```bash
bundle exec rspec
```

Generate code coverage report:

```bash
bundle exec rspec
open coverage/index.html  # View coverage report
```

Run code quality checks:

```bash
bundle exec rubocop
bundle exec brakeman
```

## Development

After checking out the repo, run:

```bash
bin/setup
```

To install dependencies. Then, run:

```bash
rake
```

To run the tests, RuboCop, and Brakeman.

## Architecture

JPie follows a clean architecture with distinct responsibilities:

- **Resource**: Defines the structure and attributes of your API resources
- **Serializer**: Converts Ruby objects to JSON:API format
- **Deserializer**: Converts JSON:API format to Ruby hashes
- **Controller**: Provides Rails integration and error handling
- **Configuration**: Manages gem-wide settings

Each class is designed to be:
- **Single Responsibility**: Each class has one clear purpose
- **Open/Closed**: Extensible without modification
- **Dependency Inversion**: Depends on abstractions, not concretions

## Roadmap

The initial version focuses on basic JSON:API serialization/deserialization with attributes only. Future versions will add:

- Relationships (has_one, has_many, belongs_to)
- Sparse fieldsets
- Inclusion of related resources
- Sorting
- Pagination
- Filtering
- Meta information
- Links

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/emilkampp/jpie.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Run the test suite (`rake`)
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create a new Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Support

- Documentation: [GitHub Wiki](https://github.com/emilkampp/jpie/wiki)
- Issues: [GitHub Issues](https://github.com/emilkampp/jpie/issues)
- Discussions: [GitHub Discussions](https://github.com/emilkampp/jpie/discussions) 