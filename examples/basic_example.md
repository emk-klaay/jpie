# Basic JPie Example

This example shows the minimal setup to get a JPie resource working with HTTP requests and responses.

## Setup

### 1. Model (`app/models/user.rb`)
```ruby
class User < ActiveRecord::Base
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
end
```

### 2. Resource (`app/resources/user_resource.rb`)
```ruby
class UserResource < JPie::Resource
  attributes :name, :email
end
```

### 3. Controller (`app/controllers/users_controller.rb`)
```ruby
class UsersController < ApplicationController
  include JPie::Controller
end
```

### 4. Routes (`config/routes.rb`)
```ruby
Rails.application.routes.draw do
  resources :users
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
      "name": "John Doe",
      "email": "john@example.com"
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
      "name": "John Doe",
      "email": "john@example.com"
    }
  }
}
```

### Get All Users
```http
GET /users
Accept: application/vnd.api+json

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": [
    {
      "id": "1",
      "type": "users",
      "attributes": {
        "name": "John Doe",
        "email": "john@example.com"
      }
    }
  ]
}
```

### Get Single User
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
      "name": "John Doe",
      "email": "john@example.com"
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
      "name": "Jane Doe"
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
      "name": "Jane Doe",
      "email": "john@example.com"
    }
  }
}
```

### Delete User
```http
DELETE /users/1
Accept: application/vnd.api+json

HTTP/1.1 204 No Content
``` 