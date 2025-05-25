# Meta Field Configuration Example

This example demonstrates all the different ways to define and configure meta fields in JPie, focusing on the various configuration patterns and syntax options available.

## Setup

### 1. Article model
```ruby
class Article < ActiveRecord::Base
  validates :title, presence: true
  validates :content, presence: true
  validates :status, inclusion: { in: %w[draft published archived] }
  
  belongs_to :author, class_name: 'User'
  
  def word_count
    content.split.length
  end
  
  def reading_time_minutes
    (word_count / 200.0).ceil
  end
end
```

### 2. Resource with All Meta Field Configuration Types 
```ruby
class ArticleResource < JPie::Resource
  # Regular attributes
  attributes :title, :content, :status
  
  # 1. Basic meta attributes - direct model attribute access
  meta_attributes :created_at, :updated_at, :published_at
  
  # 2. Multiple meta attributes at once
  meta_attributes :author_id, :view_count
  
  # 3. Single meta attribute with custom method
  meta_attribute :reading_time
  
  # 4. Meta attribute with block (legacy style)
  meta_attribute :word_count do
    object.word_count
  end
  
  # 5. Meta attribute with proc block (alternative legacy style)
  meta_attribute :character_count, block: proc { object.content.length }
  
  # 6. Meta attribute with attr mapping (maps to different model attribute)
  meta_attribute :author_name, attr: :author_email
  
  # 7. Meta attribute accessing context
  meta_attribute :user_role
  
  # 8. Meta attribute with conditional logic
  meta_attribute :edit_permissions
  
  # 9. Short alias syntax (modern style)
  meta :api_version
  metas :request_id, :cache_key
  
  # 10. Custom meta method for dynamic metadata
  def meta
    # Start with declared meta attributes
    base_meta = super
    
    # Add dynamic metadata
    dynamic_meta = {
      timestamp: Time.current.iso8601,
      resource_version: '2.1'
    }
    
    # Conditional metadata based on context
    if context[:include_debug]
      dynamic_meta[:debug_info] = {
        object_class: object.class.name,
        context_keys: context.keys
      }
    end
    
    # Merge and return
    base_meta.merge(dynamic_meta)
  end
  
  private
  
  # Custom method for reading_time meta attribute
  def reading_time
    {
      minutes: object.reading_time_minutes,
      formatted: "#{object.reading_time_minutes} min read"
    }
  end
  
  # Meta attribute accessing context
  def user_role
    context[:current_user]&.role || 'anonymous'
  end
  
  # Meta attribute with conditional logic
  def edit_permissions
    current_user = context[:current_user]
    return false unless current_user
    
    current_user.admin? || current_user == object.author
  end
  
  # Meta attributes using short alias syntax
  def api_version
    '1.0'
  end
  
  def request_id
    context[:request_id] || SecureRandom.uuid
  end
  
  def cache_key
    "article:#{object.id}:#{object.updated_at.to_i}"
  end
end
```

## HTTP Examples

### Create Article
```http
POST /articles
Content-Type: application/vnd.api+json
Authorization: Bearer user_token

{
  "data": {
    "type": "articles",
    "attributes": {
      "title": "Meta Field Configuration Guide",
      "content": "This guide demonstrates all the different ways to configure meta fields in JPie...",
      "status": "draft"
    }
  }
}

HTTP/1.1 201 Created
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "articles",
    "attributes": {
      "title": "Meta Field Configuration Guide",
      "content": "This guide demonstrates all the different ways to configure meta fields in JPie...",
      "status": "draft"
    },
    "meta": {
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z",
      "published_at": null,
      "author_id": 123,
      "view_count": 0,
      "reading_time": {
        "minutes": 3,
        "formatted": "3 min read"
      },
      "word_count": 450,
      "character_count": 2700,
      "author_name": "john@example.com",
      "user_role": "editor",
      "edit_permissions": true,
      "api_version": "1.0",
      "request_id": "req_abc123def456",
      "cache_key": "article:1:1705492800",
      "timestamp": "2024-03-15T16:45:30Z",
      "resource_version": "2.1"
    }
  }
}
```

### Update Article
```http
PATCH /articles/1
Content-Type: application/vnd.api+json
Authorization: Bearer user_token

{
  "data": {
    "id": "1",
    "type": "articles",
    "attributes": {
      "status": "published"
    }
  }
}

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "articles",
    "attributes": {
      "title": "Meta Field Configuration Guide",
      "content": "This guide demonstrates all the different ways to configure meta fields in JPie...",
      "status": "published"
    },
    "meta": {
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-16T14:20:00Z",
      "published_at": "2024-01-16T09:00:00Z",
      "author_id": 123,
      "view_count": 1547,
      "reading_time": {
        "minutes": 3,
        "formatted": "3 min read"
      },
      "word_count": 450,
      "character_count": 2700,
      "author_name": "john@example.com",
      "user_role": "editor",
      "edit_permissions": true,
      "api_version": "1.0",
      "request_id": "req_xyz789ghi012",
      "cache_key": "article:1:1705492800",
      "timestamp": "2024-03-15T16:45:30Z",
      "resource_version": "2.1"
    }
  }
}
```

### Get Article with All Meta Field Configurations
```http
GET /articles/1
Accept: application/vnd.api+json
Authorization: Bearer user_token

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "articles",
    "attributes": {
      "title": "Meta Field Configuration Guide",
      "content": "This guide demonstrates all the different ways to configure meta fields in JPie...",
      "status": "published"
    },
    "meta": {
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-16T14:20:00Z",
      "published_at": "2024-01-16T09:00:00Z",
      "author_id": 123,
      "view_count": 1547,
      "reading_time": {
        "minutes": 3,
        "formatted": "3 min read"
      },
      "word_count": 450,
      "character_count": 2700,
      "author_name": "john@example.com",
      "user_role": "editor",
      "edit_permissions": true,
      "api_version": "1.0",
      "request_id": "req_abc123def456",
      "cache_key": "article:1:1705492800",
      "timestamp": "2024-03-15T16:45:30Z",
      "resource_version": "2.1"
    }
  }
}
```