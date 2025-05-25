# frozen_string_literal: true

# Polymorphic Associations Example
# This example demonstrates how to use polymorphic associations with JPie resources

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
end

# Post model with has_many polymorphic association
class Post < ApplicationRecord
  has_many :comments, as: :commentable, dependent: :destroy
  belongs_to :author, class_name: 'User'
  
  validates :title, :content, presence: true
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

class CommentsController < ApplicationController
  include JPie::Controller
  
  # Override create to handle polymorphic assignment
  def create
    attributes = deserialize_params
    commentable = find_commentable
    
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

class PostsController < ApplicationController
  include JPie::Controller
  
  # Override create to set the author
  def create
    attributes = deserialize_params
    post = Post.new(attributes)
    post.author = current_user
    post.save!
    
    render_jsonapi(post, status: :created)
  end
end

class ArticlesController < ApplicationController
  include JPie::Controller
  
  # Override create to set the author
  def create
    attributes = deserialize_params
    article = Article.new(attributes)
    article.author = current_user
    article.save!
    
    render_jsonapi(article, status: :created)
  end
end

class VideosController < ApplicationController
  include JPie::Controller
  
  # Override create to set the author
  def create
    attributes = deserialize_params
    video = Video.new(attributes)
    video.author = current_user
    video.save!
    
    render_jsonapi(video, status: :created)
  end
end

class UsersController < ApplicationController
  include JPie::Controller
  # Uses default CRUD operations
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