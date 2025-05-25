# Resource Attribute Overrides Example

This example demonstrates all the different ways to override resource attributes in JPie, showcasing the various override patterns and customization techniques available for attributes.

## Setup

### 1. Model (`app/models/user.rb`)
```ruby
class User < ActiveRecord::Base
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, uniqueness: true
  
  def active?
    active
  end
  
  def last_login_formatted
    last_login&.strftime('%B %d, %Y at %I:%M %p')
  end
end
```

### 2. Resource with All Attribute Override Types (`app/resources/user_resource.rb`)
```ruby
class UserResource < JPie::Resource
  # 1. Basic attributes - uses default model attribute access
  attributes :email, :first_name, :last_name
  
  # 2. Attribute with custom attr mapping (maps to different model attribute)
  attribute :display_name, attr: :username
  
  # 3. Attribute with block override (legacy style)
  attribute :status do
    object.active? ? 'active' : 'inactive'
  end
  
  # 4. Attribute with options block (alternative legacy style)
  attribute :account_type, block: proc { 
    object.admin? ? 'administrator' : 'user' 
  }
  
  # 5. Attribute with custom method override (modern approach)
  attribute :full_name
  
  # 6. Attribute accessing context
  attribute :display_role
  
  # 7. Attribute with complex computation
  attribute :account_summary
  
  # 8. Attribute that delegates to model method
  attribute :formatted_last_login
  
  # 9. Attribute with conditional logic based on context
  attribute :sensitive_data
  
  private
  
  # Method override for custom attribute logic
  def full_name
    "#{object.first_name} #{object.last_name}".strip
  end
  
  # Attribute with context access
  def display_role
    if context[:current_user]&.admin?
      "Admin View: #{object.email}"
    else
      "User: #{object.first_name}"
    end
  end
  
  # Complex computation attribute
  def account_summary
    {
      name: full_name,
      status: object.active? ? 'active' : 'inactive',
      email_domain: object.email.split('@').last,
      created_days_ago: ((Time.current - object.created_at) / 1.day).round
    }
  end
  
  # Delegate to model method
  def formatted_last_login
    object.last_login_formatted || 'Never logged in'
  end
  
  # Conditional attribute based on context
  def sensitive_data
    if context[:current_user]&.admin?
      {
        internal_id: object.id,
        created_at: object.created_at,
        last_login: object.last_login
      }
    else
      'Access denied'
    end
  end
end
```

### 3. Controller (`app/controllers/users_controller.rb`)
```ruby
class UsersController < ApplicationController
  include JPie::Controller
  
  private
  
  def context
    super.merge(current_user: current_user)
  end
end
```

## HTTP Examples

### Create User
```http
POST /users
Content-Type: application/vnd.api+json
Authorization: Bearer admin_token

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
      "account_type": "user",
      "full_name": "John Doe",
      "display_role": "Admin View: john.doe@example.com",
      "account_summary": {
        "name": "John Doe",
        "status": "active",
        "email_domain": "example.com",
        "created_days_ago": 0
      },
      "formatted_last_login": "Never logged in",
      "sensitive_data": {
        "internal_id": 1,
        "created_at": "2024-01-15T10:30:00Z",
        "last_login": null
      }
    }
  }
}
```

### Update User
```http
PATCH /users/1
Content-Type: application/vnd.api+json
Authorization: Bearer admin_token

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
      "account_type": "user",
      "full_name": "Jonathan Doe",
      "display_role": "Admin View: john.doe@example.com",
      "account_summary": {
        "name": "Jonathan Doe",
        "status": "active",
        "email_domain": "example.com",
        "created_days_ago": 45
      },
      "formatted_last_login": "March 15, 2024 at 02:30 PM",
      "sensitive_data": {
        "internal_id": 1,
        "created_at": "2023-01-15T10:30:00Z",
        "last_login": "2024-03-15T14:30:00Z"
      }
    }
  }
}
```

### Get User with All Attribute Override Types (Admin Context)
```http
GET /users/1
Accept: application/vnd.api+json
Authorization: Bearer admin_token

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
      "account_type": "user",
      "full_name": "John Doe",
      "display_role": "Admin View: john.doe@example.com",
      "account_summary": {
        "name": "John Doe",
        "status": "active",
        "email_domain": "example.com",
        "created_days_ago": 45
      },
      "formatted_last_login": "March 15, 2024 at 02:30 PM",
      "sensitive_data": {
        "internal_id": 1,
        "created_at": "2023-01-15T10:30:00Z",
        "last_login": "2024-03-15T14:30:00Z"
      }
    }
  }
}
```

### Get User with Regular User Context
```http
GET /users/1
Accept: application/vnd.api+json
Authorization: Bearer user_token

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
      "account_type": "user",
      "full_name": "John Doe",
      "display_role": "User: John",
      "account_summary": {
        "name": "John Doe",
        "status": "active",
        "email_domain": "example.com",
        "created_days_ago": 45
      },
      "formatted_last_login": "March 15, 2024 at 02:30 PM",
      "sensitive_data": "Access denied"
    }
  }
}
```

### Get User with No Authentication Context
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
      "account_type": "user",
      "full_name": "John Doe",
      "display_role": "User: John",
      "account_summary": {
        "name": "John Doe",
        "status": "active",
        "email_domain": "example.com",
        "created_days_ago": 45
      },
      "formatted_last_login": "Never logged in",
      "sensitive_data": "Access denied"
    }
  }
}
```