# frozen_string_literal: true

# Polymorphic Associations Example
# This example demonstrates how to use polymorphic associations with JPie resources
# and how JPie automatically handles polymorphic associations.

# ==============================================================================
# JPIE AUTOMATIC POLYMORPHIC HANDLING
# ==============================================================================

# JPie automatically handles:
# 1. Polymorphic association creation via nested routes (POST /posts/1/comments)
# 2. Setting belongs_to associations from current_user
# 3. Standard CRUD operations for polymorphic resources
# 4. Proper JSON:API serialization of polymorphic relationships
#
# No controller overrides needed unless you have custom business logic!

# ==============================================================================
# 1. MODELS WITH POLYMORPHIC ASSOCIATIONS
# ==============================================================================

# Comment model with belongs_to polymorphic association
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
  belongs_to :author, class_name: 'User'
  
  validates :content, presence: true
  validates :commentable, presence: true
  validates :author, presence: true
  
  # JPie can automatically set author from current_user if this callback is defined
  before_validation :set_author_from_context, on: :create
  
  private
  
  def set_author_from_context
    # This would be called by JPie automatically
    self.author ||= Current.user if defined?(Current.user)
  end
end

# Post model with has_many polymorphic association
class Post < ApplicationRecord
  has_many :comments, as: :commentable, dependent: :destroy
  belongs_to :author, class_name: 'User'
  
  validates :title, :content, presence: true
  
  # Example of business logic that might require controller override
  def comments_disabled?
    # Custom business logic
    closed_for_comments || created_at < 30.days.ago
  end
end

# Article model with has_many polymorphic association  
class Article < ApplicationRecord
  has_many :comments, as: :commentable, dependent: :destroy
  belongs_to :author, class_name: 'User'
  
  validates :title, :body, presence: true
end

# Video model with has_many polymorphic association
class Video < ApplicationRecord
  has_many :comments, as: :commentable, dependent: :destroy
  belongs_to :author, class_name: 'User'
  
  validates :title, :url, presence: true
end

# User model
class User < ApplicationRecord
  has_many :posts, foreign_key: 'author_id', dependent: :destroy
  has_many :articles, foreign_key: 'author_id', dependent: :destroy
  has_many :videos, foreign_key: 'author_id', dependent: :destroy
  has_many :comments, foreign_key: 'author_id', dependent: :destroy
  
  validates :name, :email, presence: true
end

# ==============================================================================
# 2. RESOURCES FOR POLYMORPHIC ASSOCIATIONS
# ==============================================================================

# Configure JPie to automatically handle common patterns
class ApplicationController < ActionController::Base
  include JPie::Controller
  
  private
  
  # JPie can use this method to automatically set author on create
  def current_user
    # Your authentication logic here
    User.find(session[:user_id]) if session[:user_id]
  end
end

# Comment resource
class CommentResource < JPie::Resource
  attributes :content
  meta_attributes :created_at, :updated_at
  
  # Relationships
  has_one :author, resource: 'UserResource'
  
  private
  
  def author
    object.author
  end
end

# Post resource  
class PostResource < JPie::Resource
  attributes :title, :content
  meta_attributes :created_at, :updated_at
  
  # Relationships
  has_many :comments
  has_one :author, resource: 'UserResource'
  
  private
  
  def comments
    object.comments
  end
  
  def author
    object.author
  end
end

# Article resource
class ArticleResource < JPie::Resource
  attributes :title, :body
  meta_attributes :created_at, :updated_at
  
  # Relationships
  has_many :comments
  has_one :author, resource: 'UserResource'
  
  private
  
  def comments
    object.comments
  end
  
  def author
    object.author
  end
end

# Video resource
class VideoResource < JPie::Resource
  attributes :title, :url, :duration
  meta_attributes :created_at, :updated_at
  
  # Relationships
  has_many :comments
  has_one :author, resource: 'UserResource'
  
  private
  
  def comments
    object.comments
  end
  
  def author
    object.author
  end
end

# User resource
class UserResource < JPie::Resource
  attributes :name, :email
  meta_attributes :created_at, :updated_at
  
  # Relationships
  has_many :posts
  has_many :articles
  has_many :videos
  has_many :comments
end

# ==============================================================================
# 3. CONTROLLERS FOR POLYMORPHIC RESOURCES
# ==============================================================================

# JPie automatically handles polymorphic associations!
# No controller overrides needed for basic CRUD operations.

class CommentsController < ApplicationController
  include JPie::Controller
  # JPie automatically handles:
  # - Polymorphic association creation via nested routes
  # - Setting author from current_user (if configured)
  # - Standard CRUD operations
end

class PostsController < ApplicationController
  include JPie::Controller
  # JPie automatically handles author assignment from current_user
end

class ArticlesController < ApplicationController
  include JPie::Controller
  # JPie automatically handles author assignment from current_user
end

class VideosController < ApplicationController
  include JPie::Controller
  # JPie automatically handles author assignment from current_user
end

class UsersController < ApplicationController
  include JPie::Controller
end

# ==============================================================================
# 3B. MANUAL CONTROLLER OVERRIDES (when needed for complex logic)
# ==============================================================================

# Only override controllers when you need custom business logic
class AdvancedCommentsController < ApplicationController
  include JPie::Controller
  
  # Override only when you need custom validation or business logic
  def create
    attributes = deserialize_params
    commentable = find_commentable
    
    # Custom business logic example
    if commentable.is_a?(Post) && commentable.comments_disabled?
      raise JPie::Errors::Error.new(
        status: 422,
        title: 'Comments Disabled',
        detail: 'Comments are disabled for this post'
      )
    end
    
    comment = commentable.comments.build(attributes)
    comment.author = current_user
    comment.save!
    
    render_jsonapi(comment, status: :created)
  end
  
  private
  
  def find_commentable
    # Extract commentable info from request path or parameters
    if params[:post_id]
      Post.find(params[:post_id])
    elsif params[:article_id]
      Article.find(params[:article_id])
    elsif params[:video_id]
      Video.find(params[:video_id])
    else
      raise ArgumentError, "Commentable not specified"
    end
  end
end

# ==============================================================================
# 4. ROUTES FOR POLYMORPHIC RESOURCES
# ==============================================================================

# config/routes.rb
Rails.application.routes.draw do
  # Nested routes for polymorphic comments
  resources :posts do
    resources :comments, only: [:index, :create]
  end
  
  resources :articles do
    resources :comments, only: [:index, :create]
  end
  
  resources :videos do
    resources :comments, only: [:index, :create]
  end
  
  # Direct comment routes
  resources :comments, only: [:show, :update, :destroy]
  
  # Other resources
  resources :users
end

# ==============================================================================
# 5. ADVANCED POLYMORPHIC RESOURCE WITH COMMENTABLE INFO
# ==============================================================================

class CommentResourceWithCommentableInfo < JPie::Resource
  attributes :content
  meta_attributes :created_at, :updated_at
  
  # Custom attributes to expose commentable information
  attribute :commentable_type
  attribute :commentable_id
  
  # Relationships
  has_one :author, resource: 'UserResource'
  
  private
  
  def commentable_type
    object.commentable_type.downcase.pluralize
  end
  
  def commentable_id
    object.commentable_id.to_s
  end
  
  def author
    object.author
  end
end

# ==============================================================================
# 6. EXAMPLE API REQUESTS AND RESPONSES
# ==============================================================================

# GET /posts/1?include=comments,comments.author
# Response shows post with polymorphic comments and their authors:
{
  "data": {
    "id": "1",
    "type": "posts",
    "attributes": {
      "title": "My First Post",
      "content": "This is the content of my first post."
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
        "content": "Great post!"
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
        "content": "Thanks for sharing!"
      },
      "meta": {
        "created_at": "2024-01-15T12:00:00Z",
        "updated_at": "2024-01-15T12:00:00Z"
      }
    },
    {
      "id": "5",
      "type": "users",
      "attributes": {
        "name": "John Doe",
        "email": "john@example.com"
      }
    },
    {
      "id": "6",
      "type": "users",
      "attributes": {
        "name": "Jane Smith",
        "email": "jane@example.com"
      }
    }
  ]
}

# GET /articles/1?include=comments,comments.author
# Response shows article with the same comment structure (polymorphic!)

# GET /videos/1?include=comments,comments.author
# Response shows video with the same comment structure (polymorphic!)

# POST /posts/1/comments
# Request to create a comment on a post:
{
  "data": {
    "type": "comments",
    "attributes": {
      "content": "This is a great post!"
    }
  }
}

# JPie automatically:
# 1. Finds the post via params[:post_id]
# 2. Sets comment.commentable = post (polymorphic association)
# 3. Sets comment.author = current_user
# 4. Validates and saves the comment

# Response (201 Created):
{
  "data": {
    "id": "3",
    "type": "comments",
    "attributes": {
      "content": "This is a great post!"
    },
    "meta": {
      "created_at": "2024-01-15T14:30:00Z",
      "updated_at": "2024-01-15T14:30:00Z"
    }
  }
}

# POST /articles/1/comments  
# Works exactly the same way for articles (polymorphic!)

# POST /videos/1/comments
# Works exactly the same way for videos (polymorphic!)

# ==============================================================================
# 7. POLYMORPHIC RESOURCE WITH DYNAMIC TYPE RESOLUTION
# ==============================================================================

class DynamicCommentResource < JPie::Resource
  attributes :content
  meta_attributes :created_at, :updated_at
  
  # Dynamic attribute that shows different information based on commentable type
  attribute :context_info
  
  has_one :author, resource: 'UserResource'
  
  private
  
  def context_info
    case object.commentable_type
    when 'Post'
      {
        type: 'blog_comment',
        post_title: object.commentable.title,
        post_id: object.commentable.id
      }
    when 'Article'
      {
        type: 'article_comment',
        article_title: object.commentable.title,
        article_id: object.commentable.id,
        reading_time: estimate_reading_time(object.commentable.body)
      }
    when 'Video'
      {
        type: 'video_comment',
        video_title: object.commentable.title,
        video_id: object.commentable.id,
        video_duration: object.commentable.duration
      }
    else
      {
        type: 'generic_comment',
        commentable_type: object.commentable_type,
        commentable_id: object.commentable_id
      }
    end
  end
  
  def estimate_reading_time(text)
    words = text.split.size
    (words / 200.0).ceil # Assuming 200 words per minute
  end
end 