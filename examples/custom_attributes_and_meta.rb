# frozen_string_literal: true

# Custom Attributes and Meta Example
# This example demonstrates how to define custom attributes and meta data in JPie resources

# ==============================================================================
# 1. MODEL SETUP
# ==============================================================================

class User < ApplicationRecord
  validates :first_name, :last_name, :email, presence: true
  
  has_many :posts, dependent: :destroy
  has_one :profile, dependent: :destroy
  
  scope :active, -> { where(active: true) }
  
  def full_name
    "#{first_name} #{last_name}"
  end
  
  def posts_count
    posts.count
  end
end

# ==============================================================================
# 2. CUSTOM ATTRIBUTES USING METHOD OVERRIDES (MODERN APPROACH)
# ==============================================================================

class UserResource < JPie::Resource
  # Basic attributes from the model
  attributes :first_name, :last_name, :email
  
  # Custom computed attributes
  attribute :full_name
  attribute :display_name
  attribute :initials
  attribute :email_domain
  
  # Meta attributes
  meta_attributes :created_at, :updated_at
  meta_attribute :user_stats
  
  # Relationships
  has_many :posts
  has_one :profile
  
  private
  
  # Custom attribute methods have access to 'object' and 'context'
  def full_name
    "#{object.first_name} #{object.last_name}"
  end
  
  def display_name
    if context[:admin]
      "#{full_name} [ADMIN] - #{object.email}"
    else
      full_name
    end
  end
  
  def initials
    "#{object.first_name.first}#{object.last_name.first}".upcase
  end
  
  def email_domain
    object.email.split('@').last
  end
  
  # Custom meta method returns a hash
  def user_stats
    {
      posts_count: object.posts.count,
      account_age_days: (Time.current - object.created_at).to_i / 1.day,
      is_active: object.active?,
      last_post_date: object.posts.maximum(:created_at)&.iso8601
    }
  end
end

# ==============================================================================
# 3. CUSTOM ATTRIBUTES USING BLOCKS (ORIGINAL APPROACH)
# ==============================================================================

class UserResourceWithBlocks < JPie::Resource
  attributes :first_name, :last_name, :email
  
  # Block-based custom attributes
  attribute :full_name do
    "#{object.first_name} #{object.last_name}"
  end
  
  attribute :greeting do
    time = Time.current.hour
    greeting = case time
              when 0..11 then "Good morning"
              when 12..17 then "Good afternoon"
              else "Good evening"
              end
    "#{greeting}, #{object.first_name}!"
  end
  
  # Context-aware attributes using blocks
  attribute :admin_info do
    if context[:current_user]&.admin?
      {
        id: object.id,
        email: object.email,
        created_at: object.created_at,
        last_sign_in: object.last_sign_in_at
      }
    else
      nil  # Non-admins don't see admin info
    end
  end
  
  # Meta attributes with blocks
  meta_attribute :computed_stats do
    {
      days_since_signup: (Time.current - object.created_at).to_i / 1.day,
      posts_this_month: object.posts.where(created_at: 1.month.ago..).count
    }
  end
end

# ==============================================================================
# 4. CUSTOM META METHOD OVERRIDE
# ==============================================================================

class UserResourceWithCustomMeta < JPie::Resource
  attributes :first_name, :last_name, :email
  meta_attributes :created_at, :updated_at
  
  # Override the meta method for complex meta data
  def meta
    # Start with base meta attributes
    base_meta = super
    
    # Add custom meta data
    custom_meta = {
      account_summary: {
        full_name: "#{object.first_name} #{object.last_name}",
        member_since: object.created_at.year,
        posts_count: object.posts.count,
        profile_complete: object.profile.present?
      },
      permissions: calculate_permissions,
      ui_preferences: {
        theme: context[:theme] || 'light',
        language: context[:locale] || 'en'
      }
    }
    
    # Merge base and custom meta
    base_meta.merge(custom_meta)
  end
  
  private
  
  def calculate_permissions
    current_user = context[:current_user]
    return { role: 'guest' } unless current_user
    
    permissions = { role: current_user.role }
    
    if current_user == object
      permissions[:can_edit] = true
      permissions[:can_delete] = true
    elsif current_user.admin?
      permissions[:can_edit] = true
      permissions[:can_delete] = true
      permissions[:can_moderate] = true
    end
    
    permissions
  end
end

# ==============================================================================
# 5. CONDITIONAL ATTRIBUTES BASED ON CONTEXT
# ==============================================================================

class UserResourceWithConditionalAttributes < JPie::Resource
  attributes :first_name, :last_name, :email
  
  # Conditional attribute - only visible to admins
  attribute :internal_notes
  
  # Conditional attribute - only visible to the user themselves
  attribute :private_email
  
  # Conditional attribute - different values based on context
  attribute :contact_info
  
  private
  
  def internal_notes
    return nil unless context[:current_user]&.admin?
    
    object.admin_notes || "No internal notes"
  end
  
  def private_email
    current_user = context[:current_user]
    return nil unless current_user&.id == object.id
    
    object.private_email
  end
  
  def contact_info
    current_user = context[:current_user]
    
    if current_user&.admin?
      {
        email: object.email,
        phone: object.phone,
        address: object.address,
        emergency_contact: object.emergency_contact
      }
    elsif current_user&.id == object.id
      {
        email: object.email,
        phone: object.phone
      }
    else
      {
        email: object.email
      }
    end
  end
end

# ==============================================================================
# 6. CONTROLLER USAGE WITH CONTEXT
# ==============================================================================

class UsersController < ApplicationController
  include JPie::Controller
  
  def index
    users = User.active
    
    # Pass context to resources
    render_jsonapi(users, context: {
      current_user: current_user,
      admin: current_user&.admin?,
      theme: params[:theme],
      locale: I18n.locale
    })
  end
  
  def show
    user = User.find(params[:id])
    
    render_jsonapi(user, context: {
      current_user: current_user,
      requesting_own_profile: current_user&.id == user.id
    })
  end
end

# ==============================================================================
# 7. EXAMPLE API RESPONSES
# ==============================================================================

# GET /users/1 (as the user themselves)
{
  "data": {
    "id": "1",
    "type": "users",
    "attributes": {
      "first_name": "John",
      "last_name": "Doe",
      "email": "john@example.com",
      "full_name": "John Doe",
      "display_name": "John Doe",
      "initials": "JD",
      "email_domain": "example.com",
      "private_email": "john.private@personal.com"
    },
    "meta": {
      "created_at": "2024-01-01T12:00:00Z",
      "updated_at": "2024-01-15T10:30:00Z",
      "user_stats": {
        "posts_count": 5,
        "account_age_days": 15,
        "is_active": true,
        "last_post_date": "2024-01-14T15:20:00Z"
      }
    }
  }
}

# GET /users/1 (as an admin)
{
  "data": {
    "id": "1",
    "type": "users",
    "attributes": {
      "first_name": "John",
      "last_name": "Doe", 
      "email": "john@example.com",
      "full_name": "John Doe",
      "display_name": "John Doe [ADMIN] - john@example.com",
      "initials": "JD",
      "email_domain": "example.com",
      "internal_notes": "Trusted user, frequent contributor"
    },
    "meta": {
      "created_at": "2024-01-01T12:00:00Z",
      "updated_at": "2024-01-15T10:30:00Z",
      "user_stats": {
        "posts_count": 5,
        "account_age_days": 15,
        "is_active": true,
        "last_post_date": "2024-01-14T15:20:00Z"
      }
    }
  }
} 