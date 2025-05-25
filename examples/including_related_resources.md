# Including Related Resources Example

This example demonstrates how to include related resources in JPie responses using the `include` parameter, showcasing various relationship types and nested includes.

## Setup

### 1. Models (`app/models/`)

```ruby
# app/models/user.rb
class User < ActiveRecord::Base
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  
  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_one :profile, dependent: :destroy
end

# app/models/post.rb
class Post < ActiveRecord::Base
  validates :title, presence: true
  validates :content, presence: true
  
  belongs_to :user
  has_many :comments, dependent: :destroy
  has_many :tags, through: :taggings
end

# app/models/comment.rb
class Comment < ActiveRecord::Base
  validates :content, presence: true
  
  belongs_to :user
  belongs_to :post
  has_many :tags, through: :taggings
end

# app/models/profile.rb
class Profile < ActiveRecord::Base
  validates :bio, presence: true
  
  belongs_to :user
end

# app/models/tag.rb
class Tag < ActiveRecord::Base
  validates :name, presence: true, uniqueness: true
  
  has_many :taggings, dependent: :destroy
  has_many :posts, through: :taggings, source: :taggable, source_type: 'Post'
  has_many :comments, through: :taggings, source: :taggable, source_type: 'Comment'
end
```

### 2. Resources (`app/resources/`)

```ruby
# app/resources/user_resource.rb
class UserResource < JPie::Resource
  attributes :name, :email
  meta_attributes :created_at, :updated_at
  
  has_many :posts
  has_many :comments
  has_one :profile
end

# app/resources/post_resource.rb
class PostResource < JPie::Resource
  attributes :title, :content
  meta_attributes :created_at, :updated_at
  
  has_one :user
  has_many :comments
  has_many :tags
end

# app/resources/comment_resource.rb
class CommentResource < JPie::Resource
  attributes :content
  meta_attributes :created_at, :updated_at
  
  has_one :user
  has_one :post
  has_many :tags
end

# app/resources/profile_resource.rb
class ProfileResource < JPie::Resource
  attributes :bio, :website
  meta_attributes :created_at, :updated_at
  
  has_one :user
end

# app/resources/tag_resource.rb
class TagResource < JPie::Resource
  attributes :name
  meta_attributes :created_at, :updated_at
  
  has_many :posts
  has_many :comments
end
```

### 3. Controller (`app/controllers/posts_controller.rb`)

```ruby
class PostsController < ApplicationController
  include JPie::Controller
end
```

## HTTP Examples

### Create Post with Included User
```http
POST /posts?include=user
Content-Type: application/vnd.api+json

{
  "data": {
    "type": "posts",
    "attributes": {
      "title": "Getting Started with JPie",
      "content": "This post explains how to use JPie...",
      "user_id": 1
    }
  }
}

HTTP/1.1 201 Created
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "posts",
    "attributes": {
      "title": "Getting Started with JPie",
      "content": "This post explains how to use JPie..."
    },
    "meta": {
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    }
  },
  "included": [
    {
      "id": "1",
      "type": "users",
      "attributes": {
        "name": "John Doe",
        "email": "john@example.com"
      },
      "meta": {
        "created_at": "2024-01-10T09:00:00Z",
        "updated_at": "2024-01-10T09:00:00Z"
      }
    }
  ]
}
```

### Update Post with Included User and Comments
```http
PATCH /posts/1?include=user,comments
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "posts",
    "attributes": {
      "title": "Advanced JPie Techniques"
    }
  }
}

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "posts",
    "attributes": {
      "title": "Advanced JPie Techniques",
      "content": "This post explains how to use JPie..."
    },
    "meta": {
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T11:00:00Z"
    }
  },
  "included": [
    {
      "id": "1",
      "type": "users",
      "attributes": {
        "name": "John Doe",
        "email": "john@example.com"
      },
      "meta": {
        "created_at": "2024-01-10T09:00:00Z",
        "updated_at": "2024-01-10T09:00:00Z"
      }
    },
    {
      "id": "1",
      "type": "comments",
      "attributes": {
        "content": "Great post! Very helpful."
      },
      "meta": {
        "created_at": "2024-01-15T11:00:00Z",
        "updated_at": "2024-01-15T11:00:00Z"
      }
    }
  ]
}
```

### Single Include - Post with User
```http
GET /posts/1?include=user
Accept: application/vnd.api+json

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "posts",
    "attributes": {
      "title": "Getting Started with JPie",
      "content": "This post explains how to use JPie..."
    },
    "meta": {
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    }
  },
  "included": [
    {
      "id": "1",
      "type": "users",
      "attributes": {
        "name": "John Doe",
        "email": "john@example.com"
      },
      "meta": {
        "created_at": "2024-01-10T09:00:00Z",
        "updated_at": "2024-01-10T09:00:00Z"
      }
    }
  ]
}
```

### Multiple Includes - Post with User and Comments
```http
GET /posts/1?include=user,comments
Accept: application/vnd.api+json

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "posts",
    "attributes": {
      "title": "Getting Started with JPie",
      "content": "This post explains how to use JPie..."
    },
    "meta": {
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    }
  },
  "included": [
    {
      "id": "1",
      "type": "users",
      "attributes": {
        "name": "John Doe",
        "email": "john@example.com"
      },
      "meta": {
        "created_at": "2024-01-10T09:00:00Z",
        "updated_at": "2024-01-10T09:00:00Z"
      }
    },
    {
      "id": "1",
      "type": "comments",
      "attributes": {
        "content": "Great post! Very helpful."
      },
      "meta": {
        "created_at": "2024-01-15T11:00:00Z",
        "updated_at": "2024-01-15T11:00:00Z"
      }
    },
    {
      "id": "2",
      "type": "comments",
      "attributes": {
        "content": "Thanks for sharing this."
      },
      "meta": {
        "created_at": "2024-01-15T12:00:00Z",
        "updated_at": "2024-01-15T12:00:00Z"
      }
    }
  ]
}
```

### Nested Includes - Post with User and User's Profile
```http
GET /posts/1?include=user.profile
Accept: application/vnd.api+json

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "posts",
    "attributes": {
      "title": "Getting Started with JPie",
      "content": "This post explains how to use JPie..."
    },
    "meta": {
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    }
  },
  "included": [
    {
      "id": "1",
      "type": "users",
      "attributes": {
        "name": "John Doe",
        "email": "john@example.com"
      },
      "meta": {
        "created_at": "2024-01-10T09:00:00Z",
        "updated_at": "2024-01-10T09:00:00Z"
      }
    },
    {
      "id": "1",
      "type": "profiles",
      "attributes": {
        "bio": "Software developer passionate about clean APIs",
        "website": "https://johndoe.dev"
      },
      "meta": {
        "created_at": "2024-01-10T09:30:00Z",
        "updated_at": "2024-01-12T14:00:00Z"
      }
    }
  ]
}
```

### Complex Nested Includes - Post with Comments and Comment Users
```http
GET /posts/1?include=comments.user
Accept: application/vnd.api+json

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "posts",
    "attributes": {
      "title": "Getting Started with JPie",
      "content": "This post explains how to use JPie..."
    },
    "meta": {
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    }
  },
  "included": [
    {
      "id": "1",
      "type": "comments",
      "attributes": {
        "content": "Great post! Very helpful."
      },
      "meta": {
        "created_at": "2024-01-15T11:00:00Z",
        "updated_at": "2024-01-15T11:00:00Z"
      }
    },
    {
      "id": "2",
      "type": "comments",
      "attributes": {
        "content": "Thanks for sharing this."
      },
      "meta": {
        "created_at": "2024-01-15T12:00:00Z",
        "updated_at": "2024-01-15T12:00:00Z"
      }
    },
    {
      "id": "1",
      "type": "users",
      "attributes": {
        "name": "John Doe",
        "email": "john@example.com"
      },
      "meta": {
        "created_at": "2024-01-10T09:00:00Z",
        "updated_at": "2024-01-10T09:00:00Z"
      }
    },
    {
      "id": "2",
      "type": "users",
      "attributes": {
        "name": "Jane Smith",
        "email": "jane@example.com"
      },
      "meta": {
        "created_at": "2024-01-12T08:00:00Z",
        "updated_at": "2024-01-12T08:00:00Z"
      }
    }
  ]
}
```

### Through Association - Post with Tags
```http
GET /posts/1?include=tags
Accept: application/vnd.api+json

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": {
    "id": "1",
    "type": "posts",
    "attributes": {
      "title": "Getting Started with JPie",
      "content": "This post explains how to use JPie..."
    },
    "meta": {
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    }
  },
  "included": [
    {
      "id": "1",
      "type": "tags",
      "attributes": {
        "name": "ruby"
      },
      "meta": {
        "created_at": "2024-01-01T00:00:00Z",
        "updated_at": "2024-01-01T00:00:00Z"
      }
    },
    {
      "id": "2",
      "type": "tags",
      "attributes": {
        "name": "api"
      },
      "meta": {
        "created_at": "2024-01-01T00:00:00Z",
        "updated_at": "2024-01-01T00:00:00Z"
      }
    }
  ]
}
``` 