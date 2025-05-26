# Routing Example

This example demonstrates how to use the `jpie_resources` routing helper to automatically configure JSON:API compliant routes with proper format constraints and relationship management.

## Setup

### 1. Models
```ruby
# app/models/article.rb
class Article < ActiveRecord::Base
  validates :title, presence: true
  validates :content, presence: true
  belongs_to :author, class_name: 'User'
  has_many :comments
end

# app/models/user.rb  
class User < ActiveRecord::Base
  has_many :articles, foreign_key: 'author_id'
end

# app/models/comment.rb
class Comment < ActiveRecord::Base
  belongs_to :article
  belongs_to :author, class_name: 'User'
end
```

### 2. Resources
```ruby
# app/resources/article_resource.rb
class ArticleResource < JPie::Resource
  attributes :title, :content, :published_at
  belongs_to :author, class_name: 'UserResource'
  has_many :comments
end

# app/resources/user_resource.rb
class UserResource < JPie::Resource
  attributes :name, :email
end

# app/resources/comment_resource.rb
class CommentResource < JPie::Resource
  attributes :body, :created_at
  belongs_to :article
  belongs_to :author, class_name: 'UserResource'
end
```

### 3. Controllers
```ruby
# app/controllers/articles_controller.rb
class ArticlesController < ApplicationController
  include JPie::Controller
end

# app/controllers/relationships_controller.rb
class RelationshipsController < ApplicationController
  include JPie::Controller
  # Handles relationship management for JSON:API
end

# app/controllers/related_controller.rb
class RelatedController < ApplicationController
  include JPie::Controller
  # Handles fetching related resources
end
```

### 4. Routes (`config/routes.rb`)
```ruby
Rails.application.routes.draw do
  # Use jpie_resources instead of resources for JSON:API routes
  jpie_resources :articles
  jpie_resources :users
  jpie_resources :comments
  
  # You can also use it with options
  jpie_resources :posts, only: %i[index show]
  
  # And with nested routes
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
        "content": "Content of first article",
        "published_at": "2024-01-01T10:00:00Z"
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

### Get Article with Relationships
```http
GET /articles/1?include=author,comments
Accept: application/vnd.api+json

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "articles",
    "attributes": {
      "title": "First Article",
      "content": "Content of first article"
    },
    "relationships": {
      "author": {
        "data": { "type": "users", "id": "1" }
      },
      "comments": {
        "data": [
          { "type": "comments", "id": "1" },
          { "type": "comments", "id": "2" }
        ]
      }
    }
  },
  "included": [
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

### Update Article Relationship
```http
PATCH /articles/1/relationships/author
Content-Type: application/vnd.api+json

{
  "data": { "type": "users", "id": "2" }
}
```

### Add Comments to Article
```http
POST /articles/1/relationships/comments
Content-Type: application/vnd.api+json

{
  "data": [
    { "type": "comments", "id": "5" },
    { "type": "comments", "id": "6" }
  ]
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