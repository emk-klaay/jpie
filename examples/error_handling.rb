# frozen_string_literal: true

# Error Handling Example
# This example demonstrates various approaches to error handling in JPie applications

# ==============================================================================
# 1. CUSTOM JPIE ERRORS
# ==============================================================================

# Define custom business logic errors
class BusinessLogicError < JPie::Errors::Error
  def initialize(detail: 'Business logic validation failed')
    super(status: 422, title: 'Business Logic Error', detail: detail)
  end
end

class AuthorizationError < JPie::Errors::Error
  def initialize(detail: 'Access denied')
    super(status: 403, title: 'Authorization Error', detail: detail)
  end
end

class ResourceNotFoundError < JPie::Errors::Error
  def initialize(resource_type:, id:)
    detail = "#{resource_type.humanize} with ID '#{id}' was not found"
    super(status: 404, title: 'Resource Not Found', detail: detail)
  end
end

class RateLimitError < JPie::Errors::Error
  def initialize(limit: 100, window: '1 hour')
    detail = "Rate limit of #{limit} requests per #{window} exceeded"
    super(status: 429, title: 'Rate Limit Exceeded', detail: detail)
  end
end

class ValidationError < JPie::Errors::Error
  def initialize(field:, message:)
    super(
      status: 422,
      title: 'Validation Error',
      detail: "#{field.humanize} #{message}",
      source: { pointer: "/data/attributes/#{field}" }
    )
  end
end

# ==============================================================================
# 2. MODELS WITH CUSTOM VALIDATIONS
# ==============================================================================

class User < ApplicationRecord
  validates :name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :age, presence: true, numericality: { greater_than: 13, less_than: 120 }
  
  has_many :posts, foreign_key: 'author_id', dependent: :destroy
  
  # Custom business logic validation
  def validate_posting_privileges
    return true if admin?
    return true if created_at < 30.days.ago
    
    raise BusinessLogicError.new(
      detail: 'New users must wait 30 days before posting'
    )
  end
  
  def validate_posting_rate_limit
    recent_posts = posts.where('created_at > ?', 1.hour.ago).count
    return true if recent_posts < 5
    
    raise RateLimitError.new(limit: 5, window: '1 hour')
  end
  
  def admin?
    # Simple admin check - in real app this might be a role or permission system
    role == 'admin'
  end
end

class Post < ApplicationRecord
  belongs_to :author, class_name: 'User'
  
  validates :title, presence: true, length: { minimum: 10, maximum: 100 }
  validates :content, presence: true, length: { minimum: 50 }
  validates :author, presence: true
  
  # Custom business validation
  def validate_content_appropriateness
    banned_words = %w[spam forbidden inappropriate]
    content_words = content.downcase.split
    
    banned_found = banned_words & content_words
    return true if banned_found.empty?
    
    raise BusinessLogicError.new(
      detail: "Content contains inappropriate words: #{banned_found.join(', ')}"
    )
  end
end

# ==============================================================================
# 3. RESOURCES WITH ERROR HANDLING
# ==============================================================================

class UserResource < JPie::Resource
  attributes :name, :email, :age
  meta_attributes :created_at, :updated_at
  
  has_many :posts
  
  # Override method to add authorization check
  def email
    current_user = context[:current_user]
    
    # Only show email to the user themselves or admins
    if current_user&.id == object.id || current_user&.admin?
      object.email
    else
      raise AuthorizationError.new(
        detail: 'Email address is private'
      )
    end
  end
end

class PostResource < JPie::Resource
  attributes :title, :content, :published
  meta_attributes :created_at, :updated_at
  
  has_one :author, resource: 'UserResource'
  
  # Override method to check read permissions
  def content
    if object.published? || can_view_unpublished?
      object.content
    else
      raise AuthorizationError.new(
        detail: 'This post is not published and you do not have permission to view it'
      )
    end
  end
  
  private
  
  def can_view_unpublished?
    current_user = context[:current_user]
    current_user&.id == object.author_id || current_user&.admin?
  end
end

# ==============================================================================
# 4. CONTROLLERS WITH COMPREHENSIVE ERROR HANDLING
# ==============================================================================

class ApplicationController < ActionController::Base
  include JPie::Controller
  
  # Option 1: Override specific JPie error handlers
  private
  
  def render_jpie_not_found_error(error)
    # Add custom logging
    Rails.logger.error "Not Found: #{error.message}"
    
    # Track the error
    ErrorTracker.notify(error) if defined?(ErrorTracker)
    
    # Call the original JPie handler
    super
  end
  
  def render_jpie_validation_error(error)
    # Log validation errors for analysis
    Rails.logger.warn "Validation Error: #{error.record.errors.full_messages}"
    
    # Custom validation error format with more detail
    errors = error.record.errors.map do |field, message|
      {
        status: "422",
        title: "Validation Error",
        detail: "#{field.humanize} #{message}",
        source: { pointer: "/data/attributes/#{field}" },
        meta: {
          field: field,
          value: error.record.public_send(field),
          validation_type: 'model_validation'
        }
      }
    end
    
    render json: { errors: errors }, 
           status: :unprocessable_entity,
           content_type: 'application/vnd.api+json'
  end
end

class UsersController < ApplicationController
  include JPie::Controller
  
  def create
    attributes = deserialize_params
    user = User.new(attributes)
    
    # Run custom validations before saving
    user.validate_posting_privileges if user.valid?
    
    user.save!
    render_jsonapi(user, status: :created)
  rescue BusinessLogicError, AuthorizationError, RateLimitError => e
    # These are handled by JPie's error system automatically
    raise e
  rescue StandardError => e
    # Log unexpected errors
    Rails.logger.error "Unexpected error in UsersController#create: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # Re-raise to let JPie handle it
    raise e
  end
  
  def show
    user = User.find(params[:id])
    
    # Add authorization check
    unless can_view_user?(user)
      raise AuthorizationError.new(
        detail: 'You do not have permission to view this user'
      )
    end
    
    render_jsonapi(user, context: { current_user: current_user })
  end
  
  private
  
  def can_view_user?(user)
    current_user&.admin? || current_user&.id == user.id
  end
end

class PostsController < ApplicationController
  include JPie::Controller
  
  def create
    attributes = deserialize_params
    post = current_user.posts.build(attributes)
    
    # Run custom business validations
    current_user.validate_posting_rate_limit
    post.validate_content_appropriateness if post.valid?
    
    post.save!
    render_jsonapi(post, status: :created)
  end
  
  def index
    posts = Post.published
    
    # Apply user-specific filtering with error handling
    if params[:author_id].present?
      author = User.find(params[:author_id])
      posts = posts.where(author: author)
    end
    
    render_jsonapi(posts, context: { current_user: current_user })
  rescue ActiveRecord::RecordNotFound
    raise ResourceNotFoundError.new(
      resource_type: 'author',
      id: params[:author_id]
    )
  end
  
  def show
    post = Post.find(params[:id])
    render_jsonapi(post, context: { current_user: current_user })
  rescue ActiveRecord::RecordNotFound
    raise ResourceNotFoundError.new(
      resource_type: 'post',
      id: params[:id]
    )
  end
end

# ==============================================================================
# 5. ADVANCED ERROR HANDLING STRATEGIES
# ==============================================================================

class AdvancedErrorController < ApplicationController
  # Option 2: Completely custom error handling
  # Note: disable_jpie_error_handlers is a hypothetical method for demonstration
  disable_jpie_error_handlers
  
  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
  rescue_from JPie::Errors::Error, with: :handle_jpie_error
  
  private
  
  def handle_standard_error(error)
    Rails.logger.error "Unhandled error: #{error.class} - #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    
    # Notify error tracking service
    ErrorTracker.notify(error) if defined?(ErrorTracker)
    
    render json: {
      errors: [{
        status: "500",
        title: "Internal Server Error",
        detail: Rails.env.production? ? "An unexpected error occurred" : error.message
      }]
    }, status: :internal_server_error, content_type: 'application/vnd.api+json'
  end
  
  def handle_not_found(error)
    render json: {
      errors: [{
        status: "404",
        title: "Resource Not Found",
        detail: error.message,
        meta: {
          resource_type: controller_name.singularize,
          id: params[:id]
        }
      }]
    }, status: :not_found, content_type: 'application/vnd.api+json'
  end
  
  def handle_validation_error(error)
    errors = error.record.errors.map do |field, message|
      {
        status: "422",
        title: "Validation Error",
        detail: "#{field.humanize} #{message}",
        source: { pointer: "/data/attributes/#{field}" },
        meta: {
          field: field,
          rejected_value: error.record.public_send(field),
          model: error.record.class.name
        }
      }
    end
    
    render json: { errors: errors }, 
           status: :unprocessable_entity,
           content_type: 'application/vnd.api+json'
  end
  
  def handle_jpie_error(error)
    render json: {
      errors: [error.to_hash]
    }, status: error.status, content_type: 'application/vnd.api+json'
  end
end

# ==============================================================================
# 6. EXAMPLE ERROR RESPONSES
# ==============================================================================

# POST /users (with validation errors)
# Request:
{
  "data": {
    "type": "users",
    "attributes": {
      "name": "A",  # Too short
      "email": "invalid-email",  # Invalid format
      "age": 5  # Too young
    }
  }
}

# Response (422 Unprocessable Entity):
{
  "errors": [
    {
      "status": "422",
      "title": "Validation Error",
      "detail": "Name is too short (minimum is 2 characters)",
      "source": { "pointer": "/data/attributes/name" },
      "meta": {
        "field": "name",
        "value": "A",
        "validation_type": "model_validation"
      }
    },
    {
      "status": "422", 
      "title": "Validation Error",
      "detail": "Email is invalid",
      "source": { "pointer": "/data/attributes/email" },
      "meta": {
        "field": "email",
        "value": "invalid-email",
        "validation_type": "model_validation"
      }
    },
    {
      "status": "422",
      "title": "Validation Error", 
      "detail": "Age must be greater than 13",
      "source": { "pointer": "/data/attributes/age" },
      "meta": {
        "field": "age",
        "value": 5,
        "validation_type": "model_validation"
      }
    }
  ]
}

# GET /users/999 (not found)
# Response (404 Not Found):
{
  "errors": [
    {
      "status": "404",
      "title": "Resource Not Found",
      "detail": "User with ID '999' was not found"
    }
  ]
}

# POST /posts (rate limit exceeded)
# Response (429 Too Many Requests):
{
  "errors": [
    {
      "status": "429",
      "title": "Rate Limit Exceeded",
      "detail": "Rate limit of 5 requests per 1 hour exceeded"
    }
  ]
}

# GET /users/1/email (authorization error)
# Response (403 Forbidden):
{
  "errors": [
    {
      "status": "403",
      "title": "Authorization Error", 
      "detail": "Email address is private"
    }
  ]
} 