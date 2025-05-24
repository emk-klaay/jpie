# frozen_string_literal: true

# Resource classes for testing
class UserResource < JPie::Resource
  attributes :name, :email
  meta_attributes :created_at, :updated_at
  has_many :posts
  has_many :comments
  has_many :likes
end

class PostResource < JPie::Resource
  model Post
  type 'posts'

  attributes :title, :content
  meta_attributes :created_at, :updated_at
  has_one :user
  has_many :comments
  has_many :tags
  # NOTE: No has_many :taggings - join table is hidden
end

class CommentResource < JPie::Resource
  model Comment
  type 'comments'

  attributes :content
  meta_attributes :created_at, :updated_at
  has_one :user
  has_one :post
  has_one :parent_comment, resource: 'CommentResource'
  has_many :likes
  has_many :replies, resource: 'CommentResource'
  has_many :tags
  # NOTE: No has_many :taggings - join table is hidden
end

class LikeResource < JPie::Resource
  meta_attributes :created_at, :updated_at
  has_one :user
  has_one :comment
end

class TagResource < JPie::Resource
  model Tag
  type 'tags'

  attributes :name
  meta_attributes :created_at, :updated_at

  # Provide semantic names instead of exposing the join table
  has_many :tagged_posts, attr: :posts, resource: 'PostResource'
  has_many :tagged_comments, attr: :comments, resource: 'CommentResource'

  # Alternative: if you want to use the same names as ActiveRecord
  has_many :posts
  has_many :comments

  # NOTE: No has_many :taggings - join table is hidden
end

class TaggingResource < JPie::Resource
  meta_attributes :created_at, :updated_at
  has_one :tag
  has_one :taggable
end

# STI Resource classes for testing
class VehicleResource < JPie::Resource
  attributes :name, :brand, :year
  meta_attributes :created_at, :updated_at
end

class CarResource < VehicleResource
  attributes :engine_size
end

class TruckResource < VehicleResource
  attributes :cargo_capacity
end
