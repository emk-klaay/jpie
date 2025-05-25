# frozen_string_literal: true

# Custom Sorting Example
# This example demonstrates how to implement custom sorting in JPie resources

# ==============================================================================
# 1. MODEL WITH SORTING NEEDS
# ==============================================================================

class Post < ActiveRecord::Base
  belongs_to :author, class_name: 'User'
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  
  validates :title, :content, presence: true
  
  scope :published, -> { where(published: true) }
  scope :featured, -> { where(featured: true) }
  
  def popularity_score
    # Complex popularity calculation
    likes_weight = likes.count * 2
    comments_weight = comments.count * 1.5
    bookmarks_weight = bookmarks.count * 3
    recency_weight = [(Date.current - created_at.to_date).to_i, 30].min
    
    (likes_weight + comments_weight + bookmarks_weight - recency_weight).round(2)
  end
  
  def engagement_rate
    total_interactions = likes.count + comments.count + bookmarks.count
    return 0 if total_interactions.zero?
    
    # Assuming some view count logic
    view_count = rand(100..1000) # In real app, this would be actual view tracking
    (total_interactions.to_f / view_count * 100).round(2)
  end
end

class User < ActiveRecord::Base
  has_many :posts, foreign_key: 'author_id', dependent: :destroy
  
  validates :name, :email, presence: true
  
  def reputation_score
    posts.sum(&:popularity_score) / [posts.count, 1].max
  end
end

# ==============================================================================
# 2. BASIC CUSTOM SORTING
# ==============================================================================

class PostResource < JPie::Resource
  attributes :title, :content, :published
  meta_attributes :created_at, :updated_at
  
  has_one :author, resource: 'UserResource'
  has_many :comments
  
  # Simple custom sorting fields
  sortable :popularity do |query, direction|
    # Sort by a computed value using a subquery
    likes_count = Like.where('likes.post_id = posts.id').count
    comments_count = Comment.where('comments.post_id = posts.id').count
    
    if direction == :asc
      query.order(
        Arel.sql('(SELECT COUNT(*) FROM likes WHERE post_id = posts.id) * 2 + 
                  (SELECT COUNT(*) FROM comments WHERE post_id = posts.id) * 1.5')
      )
    else
      query.order(
        Arel.sql('(SELECT COUNT(*) FROM likes WHERE post_id = posts.id) * 2 + 
                  (SELECT COUNT(*) FROM comments WHERE post_id = posts.id) * 1.5 DESC')
      )
    end
  end
  
  sortable :engagement do |query, direction|
    # Sort by engagement rate (comments + likes per view)
    query.joins(:likes, :comments)
         .group('posts.id')
         .order("COUNT(DISTINCT likes.id) + COUNT(DISTINCT comments.id) #{direction.to_s.upcase}")
  end
  
  sortable :author_name do |query, direction|
    # Sort by related model attribute
    query.joins(:author).order("users.name #{direction.to_s.upcase}")
  end
  
  # Alias for backward compatibility
  sortable_by :trending, &method(:popularity)
end

# ==============================================================================
# 3. ADVANCED CUSTOM SORTING WITH MULTIPLE CRITERIA
# ==============================================================================

class AdvancedPostResource < JPie::Resource
  attributes :title, :content, :published
  meta_attributes :created_at, :updated_at
  
  # Complex multi-criteria sorting
  sortable :hot do |query, direction|
    # "Hot" algorithm: combination of popularity and recency
    if direction == :asc
      query.order(
        Arel.sql('
          (SELECT COUNT(*) FROM likes WHERE post_id = posts.id) * 2 + 
          (SELECT COUNT(*) FROM comments WHERE post_id = posts.id) * 1.5 -
          EXTRACT(DAY FROM NOW() - posts.created_at)
        ')
      )
    else
      query.order(
        Arel.sql('
          (SELECT COUNT(*) FROM likes WHERE post_id = posts.id) * 2 + 
          (SELECT COUNT(*) FROM comments WHERE post_id = posts.id) * 1.5 -
          EXTRACT(DAY FROM NOW() - posts.created_at) DESC
        ')
      )
    end
  end
  
  sortable :controversial do |query, direction|
    # Posts with high engagement but mixed reactions
    query.joins(:likes, :comments)
         .group('posts.id')
         .having('COUNT(comments.id) > ?', 10)
         .order("COUNT(comments.id) / COUNT(likes.id) #{direction.to_s.upcase}")
  end
  
  sortable :quality do |query, direction|
    # Quality score based on author reputation and post engagement
    query.joins(:author)
         .select('posts.*, 
                  (users.reputation_score * 0.3 + 
                   (SELECT COUNT(*) FROM likes WHERE post_id = posts.id) * 0.4 +
                   (SELECT COUNT(*) FROM bookmarks WHERE post_id = posts.id) * 0.3) as quality_score')
         .order("quality_score #{direction.to_s.upcase}")
  end
end

# ==============================================================================
# 4. CONDITIONAL SORTING BASED ON CONTEXT
# ==============================================================================

class ContextualPostResource < JPie::Resource
  attributes :title, :content, :published
  meta_attributes :created_at, :updated_at
  
  sortable :personalized do |query, direction|
    # This is a placeholder - in a real app, you'd access context here
    # For now, we'll show how you might structure this
    
    # Note: In actual implementation, you'd need to pass context to the sorting method
    # This might require extending JPie's sorting system
    
    if direction == :asc
      query.order(:created_at)
    else
      query.order(created_at: :desc)
    end
  end
  
  sortable :relevance do |query, direction|
    # Sort by relevance to user's interests (placeholder implementation)
    # In real app, this would use user preferences, past interactions, etc.
    
    query.joins(:author)
         .order("posts.created_at #{direction.to_s.upcase}")
  end
end

# ==============================================================================
# 5. CONTROLLER WITH CUSTOM SORTING
# ==============================================================================

class PostsController < ApplicationController
  include JPie::Controller
  
  def index
    posts = Post.published
    
    # Apply custom filters before sorting
    posts = posts.featured if params[:featured] == 'true'
    posts = posts.where(author: current_user) if params[:my_posts] == 'true'
    
    # Add context for personalized sorting (if implemented)
    render_jsonapi(posts, context: {
      current_user: current_user,
      user_preferences: current_user&.preferences
    })
  end
  
  # Custom endpoint for trending posts
  def trending
    posts = Post.published
    
    # Apply trending sort by default
    sorted_posts = resource_class.apply_sort(posts, 'trending', :desc)
    
    render_jsonapi(sorted_posts.limit(20))
  end
  
  # Custom endpoint for hot posts
  def hot
    posts = Post.published
    
    # Apply hot sort with time window
    recent_posts = posts.where('created_at > ?', 7.days.ago)
    sorted_posts = AdvancedPostResource.apply_sort(recent_posts, 'hot', :desc)
    
    render_jsonapi(sorted_posts.limit(10), resource: AdvancedPostResource)
  end
end

# ==============================================================================
# 6. ROUTES FOR CUSTOM SORTING
# ==============================================================================

# config/routes.rb
Rails.application.routes.draw do
  resources :posts do
    collection do
      get :trending
      get :hot
    end
  end
end

# ==============================================================================
# 7. EXAMPLE API REQUESTS AND RESPONSES
# ==============================================================================

# GET /posts?sort=popularity
# Response shows posts sorted by popularity (likes * 2 + comments * 1.5):
{
  "data": [
    {
      "id": "5",
      "type": "posts",
      "attributes": {
        "title": "Most Popular Post",
        "content": "This post has lots of likes and comments",
        "published": true
      }
    },
    {
      "id": "3",
      "type": "posts", 
      "attributes": {
        "title": "Second Most Popular",
        "content": "This one is also quite popular",
        "published": true
      }
    }
  ]
}

# GET /posts?sort=-engagement
# Response shows posts sorted by engagement rate (descending):
{
  "data": [
    {
      "id": "7",
      "type": "posts",
      "attributes": {
        "title": "Highly Engaging Post",
        "content": "Lots of interaction relative to views",
        "published": true
      }
    }
  ]
}

# GET /posts?sort=author_name
# Response shows posts sorted alphabetically by author name:
{
  "data": [
    {
      "id": "1",
      "type": "posts",
      "attributes": {
        "title": "Post by Alice",
        "content": "Written by Alice Anderson",
        "published": true
      }
    },
    {
      "id": "2",
      "type": "posts",
      "attributes": {
        "title": "Post by Bob", 
        "content": "Written by Bob Brown",
        "published": true
      }
    }
  ]
}

# GET /posts/trending
# Custom endpoint with trending sort applied by default

# GET /posts/hot
# Custom endpoint using AdvancedPostResource with hot sort

# ==============================================================================
# 8. COMPLEX SORTING WITH JOINS AND SUBQUERIES
# ==============================================================================

class ComplexPostResource < JPie::Resource
  attributes :title, :content, :published
  
  # Sort by multiple related models
  sortable :author_reputation do |query, direction|
    query.joins(:author)
         .joins('LEFT JOIN posts as author_posts ON author_posts.author_id = users.id')
         .group('posts.id, users.id')
         .order("AVG(author_posts.popularity_score) #{direction.to_s.upcase}")
  end
  
  # Sort using window functions (PostgreSQL specific)
  sortable :ranking do |query, direction|
    query.select('posts.*, 
                  RANK() OVER (
                    ORDER BY 
                      (SELECT COUNT(*) FROM likes WHERE post_id = posts.id) DESC,
                      posts.created_at DESC
                  ) as rank_score')
         .order("rank_score #{direction.to_s.upcase}")
  end
  
  # Sort with complex business logic
  sortable :editorial_score do |query, direction|
    # Combines multiple factors for editorial ranking
    query.select('posts.*,
                  (CASE 
                    WHEN posts.featured THEN 100 
                    ELSE 0 
                   END +
                   CASE 
                    WHEN posts.created_at > NOW() - INTERVAL \'7 days\' THEN 50
                    WHEN posts.created_at > NOW() - INTERVAL \'30 days\' THEN 25
                    ELSE 0
                   END +
                   (SELECT COUNT(*) FROM likes WHERE post_id = posts.id) * 2 +
                   (SELECT COUNT(*) FROM comments WHERE post_id = posts.id) * 3
                  ) as editorial_score')
         .order("editorial_score #{direction.to_s.upcase}")
  end
end 