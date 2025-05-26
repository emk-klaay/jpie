# JSON:API Relationship Management

This example demonstrates how to manage relationships using JPie's JSON:API compliant relationship endpoints.

## Setup

Define your resources with relationships:

```ruby
# app/resources/user_resource.rb
class UserResource < JPie::Resource
  model User
  attributes :name, :email
  has_many :posts
end

# app/resources/post_resource.rb  
class PostResource < JPie::Resource
  model Post
  attributes :title, :content
  has_one :author, resource: 'UserResource'
end

# app/controllers/users_controller.rb
class UsersController < ApplicationController
  include JPie::Controller
end
```

Configure routes:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  jpie_resources :users
  jpie_resources :posts
end
```

## Relationship Operations

### Get Relationship Linkage

```http
GET /users/1/relationships/posts

Response:
{
  "data": [
    { "type": "posts", "id": "1" },
    { "type": "posts", "id": "3" }
  ]
}
```

### Replace Relationship

```http
PATCH /users/1/relationships/posts
Content-Type: application/vnd.api+json

{
  "data": [
    { "type": "posts", "id": "2" },
    { "type": "posts", "id": "4" }
  ]
}
```

### Add to Relationship

```http
POST /users/1/relationships/posts
Content-Type: application/vnd.api+json

{
  "data": [
    { "type": "posts", "id": "5" }
  ]
}
```

### Remove from Relationship

```http
DELETE /users/1/relationships/posts
Content-Type: application/vnd.api+json

{
  "data": [
    { "type": "posts", "id": "2" }
  ]
}
```

### Get Related Resources

```http
GET /users/1/posts

Response:
{
  "data": [
    {
      "type": "posts",
      "id": "1",
      "attributes": {
        "title": "First Post",
        "content": "Hello world!"
      }
    }
  ]
}
```
