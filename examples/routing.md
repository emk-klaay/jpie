# Routing Example

This example demonstrates how to use the `jpie_resources` routing helper to automatically configure JSON:API routes with proper format constraints.

## Setup

### 1. Model (`app/models/article.rb`)
```ruby
class Article < ActiveRecord::Base
  validates :title, presence: true
  validates :content, presence: true
end
```

### 2. Resource (`app/resources/article_resource.rb`)
```ruby
class ArticleResource < JPie::Resource
  attributes :title, :content, :published_at
end
```

### 3. Controller (`app/controllers/articles_controller.rb`)
```ruby
class ArticlesController < ApplicationController
  include JPie::Controller
end
```

### 4. Routes (`config/routes.rb`)
```ruby
Rails.application.routes.draw do
  # Use jpie_resources instead of resources for JSON:API routes
  jpie_resources :articles
  
  # You can also use it with options
  jpie_resources :posts, only: %i[index show]
  
  # And with nested routes
  jpie_resources :users do
    jpie_resources :articles
  end
end
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
        "content": "Content of first article",
        "published_at": "2024-01-01T10:00:00Z"
      }
    }
  ]
}
```

### Get Single Article
```http
GET /articles/1
Accept: application/vnd.api+json

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "articles",
    "attributes": {
      "title": "First Article",
      "content": "Content of first article",
      "published_at": "2024-01-01T10:00:00Z"
    }
  }
}
```

## Benefits

The `jpie_resources` helper automatically:
- Sets `format: :json` as the default format
- Adds `format: :json` as a route constraint
- Ensures all routes only respond to JSON:API requests
- Works with all standard Rails routing options (`only`, `except`, nested routes, etc.) 