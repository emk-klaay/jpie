# frozen_string_literal: true

# Resource classes for testing
class UserResource < JPie::Resource
  attributes :name, :email
  meta_attributes :created_at, :updated_at
  has_many :posts
  has_many :articles
  has_many :videos
  has_many :comments
  has_many :likes
end

class PostResource < JPie::Resource
  attributes :title, :content
  meta_attributes :created_at, :updated_at
  has_one :user
  has_one :author, attr: :user, resource: 'UserResource'
  has_many :comments
  has_many :tags
end

class ArticleResource < JPie::Resource
  attributes :title, :body
  meta_attributes :created_at, :updated_at
  has_one :user
  has_one :author, attr: :user, resource: 'UserResource'
  has_many :comments
  has_many :tags
end

class VideoResource < JPie::Resource
  attributes :title, :url
  meta_attributes :created_at, :updated_at
  has_one :user
  has_one :author, attr: :user, resource: 'UserResource'
  has_many :comments
  has_many :tags
end

class CommentResource < JPie::Resource
  attributes :content
  meta_attributes :created_at, :updated_at
  has_one :user
  has_one :author, attr: :user, resource: 'UserResource'
  has_one :post
  has_one :commentable, polymorphic: true
  has_one :parent_comment, resource: 'CommentResource'
  has_many :likes
  has_many :replies, resource: 'CommentResource'
  has_many :tags
end

class LikeResource < JPie::Resource
  meta_attributes :created_at, :updated_at
  has_one :user
  has_one :comment
end

class TagResource < JPie::Resource
  attributes :name
  meta_attributes :created_at, :updated_at
  has_many :posts
  has_many :comments

  # Custom relationship names
  has_many :tagged_posts, attr: :posts, resource: 'PostResource'
  has_many :tagged_comments, attr: :comments, resource: 'CommentResource'
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
