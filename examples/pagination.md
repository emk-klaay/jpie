# Pagination Example

This example demonstrates how to implement pagination with JPie resources using both simple and JSON:API standard pagination parameters.

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
  resources :articles
end
```

## HTTP Examples

### Simple Pagination Parameters

#### Get First Page with 5 Articles
```http
GET /articles?page=1&per_page=5
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
    },
    {
      "id": "2",
      "type": "articles",
      "attributes": {
        "title": "Second Article",
        "content": "Content of second article",
        "published_at": "2024-01-02T10:00:00Z"
      }
    }
  ],
  "meta": {
    "pagination": {
      "page": 1,
      "per_page": 5,
      "total_pages": 4,
      "total_count": 20
    }
  },
  "links": {
    "self": "http://example.com/articles?page=1&per_page=5",
    "first": "http://example.com/articles?page=1&per_page=5",
    "last": "http://example.com/articles?page=4&per_page=5",
    "next": "http://example.com/articles?page=2&per_page=5"
  }
}
```

#### Get Second Page
```http
GET /articles?page=2&per_page=5
Accept: application/vnd.api+json

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": [
    {
      "id": "6",
      "type": "articles",
      "attributes": {
        "title": "Sixth Article",
        "content": "Content of sixth article",
        "published_at": "2024-01-06T10:00:00Z"
      }
    }
  ],
  "meta": {
    "pagination": {
      "page": 2,
      "per_page": 5,
      "total_pages": 4,
      "total_count": 20
    }
  },
  "links": {
    "self": "http://example.com/articles?page=2&per_page=5",
    "first": "http://example.com/articles?page=1&per_page=5",
    "last": "http://example.com/articles?page=4&per_page=5",
    "prev": "http://example.com/articles?page=1&per_page=5",
    "next": "http://example.com/articles?page=3&per_page=5"
  }
}
```

### JSON:API Standard Pagination Parameters

#### Get First Page Using JSON:API Format
```http
GET /articles?page[number]=1&page[size]=3
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
    },
    {
      "id": "2",
      "type": "articles",
      "attributes": {
        "title": "Second Article",
        "content": "Content of second article",
        "published_at": "2024-01-02T10:00:00Z"
      }
    },
    {
      "id": "3",
      "type": "articles",
      "attributes": {
        "title": "Third Article",
        "content": "Content of third article",
        "published_at": "2024-01-03T10:00:00Z"
      }
    }
  ],
  "meta": {
    "pagination": {
      "page": 1,
      "per_page": 3,
      "total_pages": 7,
      "total_count": 20
    }
  },
  "links": {
    "self": "http://example.com/articles?page=1&per_page=3",
    "first": "http://example.com/articles?page=1&per_page=3",
    "last": "http://example.com/articles?page=7&per_page=3",
    "next": "http://example.com/articles?page=2&per_page=3"
  }
}
```

### Pagination with Sorting

#### Get Sorted and Paginated Results
```http
GET /articles?sort=-published_at&page=1&per_page=3
Accept: application/vnd.api+json

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": [
    {
      "id": "20",
      "type": "articles",
      "attributes": {
        "title": "Latest Article",
        "content": "Most recent content",
        "published_at": "2024-01-20T10:00:00Z"
      }
    },
    {
      "id": "19",
      "type": "articles",
      "attributes": {
        "title": "Second Latest Article",
        "content": "Second most recent content",
        "published_at": "2024-01-19T10:00:00Z"
      }
    },
    {
      "id": "18",
      "type": "articles",
      "attributes": {
        "title": "Third Latest Article",
        "content": "Third most recent content",
        "published_at": "2024-01-18T10:00:00Z"
      }
    }
  ],
  "meta": {
    "pagination": {
      "page": 1,
      "per_page": 3,
      "total_pages": 7,
      "total_count": 20
    }
  },
  "links": {
    "self": "http://example.com/articles?sort=-published_at&page=1&per_page=3",
    "first": "http://example.com/articles?sort=-published_at&page=1&per_page=3",
    "last": "http://example.com/articles?sort=-published_at&page=7&per_page=3",
    "next": "http://example.com/articles?sort=-published_at&page=2&per_page=3"
  }
}
```

### Last Page Response

#### Get Last Page
```http
GET /articles?page=4&per_page=5
Accept: application/vnd.api+json

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": [
    {
      "id": "20",
      "type": "articles",
      "attributes": {
        "title": "Last Article",
        "content": "Content of last article",
        "published_at": "2024-01-20T10:00:00Z"
      }
    }
  ],
  "meta": {
    "pagination": {
      "page": 4,
      "per_page": 5,
      "total_pages": 4,
      "total_count": 20
    }
  },
  "links": {
    "self": "http://example.com/articles?page=4&per_page=5",
    "first": "http://example.com/articles?page=1&per_page=5",
    "last": "http://example.com/articles?page=4&per_page=5",
    "prev": "http://example.com/articles?page=3&per_page=5"
  }
}
```

### Empty Results

#### Get Page Beyond Available Data
```http
GET /articles?page=10&per_page=5
Accept: application/vnd.api+json

HTTP/1.1 200 OK
Content-Type: application/vnd.api+json

{
  "data": [],
  "meta": {
    "pagination": {
      "page": 10,
      "per_page": 5,
      "total_pages": 4,
      "total_count": 20
    }
  },
  "links": {
    "self": "http://example.com/articles?page=10&per_page=5",
    "first": "http://example.com/articles?page=1&per_page=5",
    "last": "http://example.com/articles?page=4&per_page=5"
  }
}
``` 