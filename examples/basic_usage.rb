# frozen_string_literal: true

# Basic Usage Example
# This example demonstrates the fundamental setup and usage of JPie

# ==============================================================================
# 1. BASIC MODEL
# ==============================================================================

class User < ApplicationRecord
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  
  has_many :posts, dependent: :destroy
  has_one :profile, dependent: :destroy
end

# ==============================================================================
# 2. BASIC RESOURCE
# ==============================================================================

class UserResource < JPie::Resource
  # Basic attributes
  attributes :name, :email
  
  # Meta attributes (for additional data)
  meta_attributes :created_at, :updated_at
  
  # Relationships for includes
  has_many :posts
  has_one :profile
end

# ==============================================================================
# 3. BASIC CONTROLLER
# ==============================================================================

class UsersController < ApplicationController
  include JPie::Controller
  
  # That's it! JPie provides automatic CRUD operations:
  # - GET /users (index)
  # - GET /users/:id (show)
  # - POST /users (create)
  # - PATCH/PUT /users/:id (update)
  # - DELETE /users/:id (destroy)
end

# ==============================================================================
# 4. ROUTES
# ==============================================================================

# config/routes.rb
Rails.application.routes.draw do
  resources :users
end

# ==============================================================================
# 5. EXAMPLE API REQUESTS AND RESPONSES
# ==============================================================================

# GET /users
# Response:
{
  "data": [
    {
      "id": "1",
      "type": "users",
      "attributes": {
        "name": "John Doe",
        "email": "john@example.com"
      },
      "meta": {
        "created_at": "2024-01-01T12:00:00Z",
        "updated_at": "2024-01-01T12:00:00Z"
      }
    }
  ]
}

# GET /users/1?include=posts,profile
# Response:
{
  "data": {
    "id": "1",
    "type": "users",
    "attributes": {
      "name": "John Doe",
      "email": "john@example.com"
    },
    "meta": {
      "created_at": "2024-01-01T12:00:00Z",
      "updated_at": "2024-01-01T12:00:00Z"
    }
  },
  "included": [
    {
      "id": "1",
      "type": "posts",
      "attributes": {
        "title": "My First Post",
        "content": "Hello World!"
      }
    },
    {
      "id": "1",
      "type": "profiles",
      "attributes": {
        "bio": "Software developer",
        "website": "https://johndoe.com"
      }
    }
  ]
}

# POST /users
# Request:
{
  "data": {
    "type": "users",
    "attributes": {
      "name": "Jane Smith",
      "email": "jane@example.com"
    }
  }
}

# Response (201 Created):
{
  "data": {
    "id": "2",
    "type": "users",
    "attributes": {
      "name": "Jane Smith",
      "email": "jane@example.com"
    },
    "meta": {
      "created_at": "2024-01-15T10:30:00Z",
      "updated_at": "2024-01-15T10:30:00Z"
    }
  }
}

# GET /users?sort=name
# Response: Users sorted alphabetically by name

# GET /users?sort=-created_at
# Response: Users sorted by creation date (newest first) 