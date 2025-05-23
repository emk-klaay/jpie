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
  attributes :title, :content
  meta_attributes :created_at, :updated_at
  has_one :user
  has_many :comments
  has_many :tags
  has_many :taggings
end

class CommentResource < JPie::Resource
  attributes :content
  meta_attributes :created_at, :updated_at
  has_one :user
  has_one :post
  has_one :parent_comment
  has_many :likes
  has_many :replies, resource: 'CommentResource'
  has_many :tags
  has_many :taggings
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
  has_many :taggings
end

class TaggingResource < JPie::Resource
  meta_attributes :created_at, :updated_at
  has_one :tag
  has_one :taggable
end
