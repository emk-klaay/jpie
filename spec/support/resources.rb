# frozen_string_literal: true

# Resource classes for testing
class UserResource < JPie::Resource
  attributes :name, :email
  meta_attributes :created_at, :updated_at
  has_many :posts
  has_many :comments
end

class PostResource < JPie::Resource
  attributes :title, :content
  meta_attributes :created_at, :updated_at
  has_one :user
  has_many :comments
end

class CommentResource < JPie::Resource
  attributes :content
  meta_attributes :created_at, :updated_at
  has_one :user
  has_one :post
end
