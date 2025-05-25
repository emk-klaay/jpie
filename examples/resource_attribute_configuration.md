# Resource Attribute Configuration Example

This example demonstrates all the different ways to configure resource attributes in JPie, showcasing the various configuration patterns and customization techniques available for attributes.

## Setup

### 1. Model (`app/models/user.rb`)
```ruby
class User < ActiveRecord::Base
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true
  
  def active?
    true # Simple boolean for demonstration
  end
end
```

### 2. Resource with All Attribute Configuration Types (`app/resources/user_resource.rb`)
```ruby
class UserResource < JPie::Resource
  # 1. Basic attributes - direct model attribute access
  attributes :email, :first_name, :last_name
  
  # 2. Attribute with custom attr mapping (maps to different model attribute)
  attribute :display_name, attr: :username
  
  # 3. Attribute with block override
  attribute :status do
    object.active? ? 'active' : 'inactive'
  end
  
  # 4. Attribute with custom method override
  attribute :full_name
  
  private
  
  # Custom method for attribute override
  def full_name
    "#{object.first_name} #{object.last_name}".strip
  end
end
```

### 3. Controller (`app/controllers/users_controller.rb`)
```ruby
class UsersController < ApplicationController
  include JPie::Controller
end
```

## HTTP Examples

### Create User
```http
POST /users
Content-Type: application/vnd.api+json

{
  "data": {
    "type": "users",
    "attributes": {
      "email": "john.doe@example.com",
      "first_name": "John",
      "last_name": "Doe"
    }
  }
}

HTTP/1.1 201 Created
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "users",
    "attributes": {
      "email": "john.doe@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "display_name": "johndoe",
      "status": "active",
      "full_name": "John Doe"
    }
  }
}
```

### Update User
```http
PATCH /users/1
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "users",
    "attributes": {
      "first_name": "Jonathan"
    }
  }
}

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "users",
    "attributes": {
      "email": "john.doe@example.com",
      "first_name": "Jonathan",
      "last_name": "Doe",
      "display_name": "johndoe",
      "status": "active",
      "full_name": "Jonathan Doe"
    }
  }
}
```

### Get User with All Attribute Configuration Types
```http
GET /users/1
Accept: application/vnd.api+json

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "users",
    "attributes": {
      "email": "john.doe@example.com",
      "first_name": "John",
      "last_name": "Doe",
      "display_name": "johndoe",
      "status": "active",
      "full_name": "John Doe"
    }
  }
}
```