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

### Flat Configuration (`jpie_resources :articles`)
```http
# Standard RESTful routes
GET    /articles                             # ArticlesController#index
POST   /articles                             # ArticlesController#create
GET    /articles/:id                         # ArticlesController#show
PATCH  /articles/:id                         # ArticlesController#update
DELETE /articles/:id                         # ArticlesController#destroy

# JSON:API relationship routes
GET    /articles/:id/relationships/author    # ArticlesController#show_relationship
PATCH  /articles/:id/relationships/author    # ArticlesController#update_relationship
GET    /articles/:id/author                  # ArticlesController#show_related
```

### Limited Configuration (`jpie_resources :posts, only: %i[index show]`)
```http
# Only specified routes (no relationship routes)
GET    /posts                                # PostsController#index
GET    /posts/:id                            # PostsController#show
```

### Nested Configuration (`jpie_resources :categories { jpie_resources :articles }`)
```http
# Category routes
GET    /categories                            # CategoriesController#index
POST   /categories                            # CategoriesController#create
GET    /categories/:id                        # CategoriesController#show
PATCH  /categories/:id                        # CategoriesController#update
DELETE /categories/:id                        # CategoriesController#destroy
GET    /categories/:id/relationships/articles # CategoriesController#show_relationship
PATCH  /categories/:id/relationships/articles # CategoriesController#update_relationship
GET    /categories/:id/articles               # CategoriesController#show_related

# Nested article routes
GET    /categories/:category_id/articles                          # ArticlesController#index
POST   /categories/:category_id/articles                          # ArticlesController#create
GET    /categories/:category_id/articles/:id                      # ArticlesController#show
PATCH  /categories/:category_id/articles/:id                      # ArticlesController#update
DELETE /categories/:category_id/articles/:id                      # ArticlesController#destroy
GET    /categories/:category_id/articles/:id/relationships/author # ArticlesController#show_relationship
PATCH  /categories/:category_id/articles/:id/relationships/author # ArticlesController#update_relationship
GET    /categories/:category_id/articles/:id/author               # ArticlesController#show_related
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