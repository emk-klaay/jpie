# Routing Example

This example demonstrates how to use the `jpie_resources` routing helper to automatically configure JSON:API compliant routes with proper format constraints and relationship management.

## Setup

### 1. Model
```ruby
# app/models/article.rb
class Article < ActiveRecord::Base
  validates :title, presence: true
  belongs_to :author, class_name: 'User'
end
```

### 2. Resource
```ruby
# app/resources/article_resource.rb
class ArticleResource < JPie::Resource
  attributes :title, :content
  belongs_to :author, class_name: 'UserResource'
end
```

### 3. Controller
```ruby
# app/controllers/articles_controller.rb
class ArticlesController < ApplicationController
  include JPie::Controller
end
```

### 4. Routes (`config/routes.rb`)
```ruby
Rails.application.routes.draw do
  # Flat configuration - full JSON:API routes
  jpie_resources :articles
  
  # Limited configuration - only specific actions
  jpie_resources :posts, only: %i[index show]
  
  # Nested configuration - hierarchical resources
  jpie_resources :categories do
    jpie_resources :articles
  end
end
```

## Generated Routes

The `jpie_resources` helper automatically creates JSON:API compliant routes:

### Standard Resource Routes
```http
GET    /articles           # Index - list all articles
POST   /articles           # Create - create new article  
GET    /articles/:id       # Show - get specific article
PATCH  /articles/:id       # Update - update specific article
DELETE /articles/:id       # Destroy - delete specific article
```

### JSON:API Relationship Routes
```http
# Relationship management (JSON:API spec compliant)
GET    /articles/:id/relationships/author    # Get relationship linkage
PATCH  /articles/:id/relationships/author    # Update relationship
POST   /articles/:id/relationships/comments  # Add to relationship
DELETE /articles/:id/relationships/comments  # Remove from relationship

# Related resource access
GET    /articles/:id/author                  # Get related author
GET    /articles/:id/comments                # Get related comments
```

## HTTP Examples

### Get All Articles
```http
GET /articles
Accept: application/vnd.api+json

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": [
    {
      "id": "1",
      "type": "articles",
      "attributes": {
        "title": "First Article",
        "content": "Content of first article"
      },
      "relationships": {
        "author": {
          "links": {
            "self": "/articles/1/relationships/author",
            "related": "/articles/1/author"
          }
        }
      }
    }
  ]
}
```

### Update Article Relationship
```http
PATCH /articles/1/relationships/author
Content-Type: application/vnd.api+json

{
  "data": { "type": "users", "id": "2" }
}
```

## Benefits

The `jpie_resources` helper automatically:
- Sets `format: :json` as the default format
- Adds `format: :json` as a route constraint
- Creates JSON:API compliant relationship routes
- Generates routes for relationship management (PATCH, POST, DELETE)
- Provides routes for fetching related resources
- Ensures all routes only respond to JSON:API requests
- Works with all standard Rails routing options (`only`, `except`, nested routes, etc.) 