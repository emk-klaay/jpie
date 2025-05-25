# frozen_string_literal: true

# Resource classes for testing
class UserResource < JPie::Resource
  attributes :name, :email
  meta_attributes :created_at, :updated_at
  has_many :posts
end

class PostResource < JPie::Resource
  attributes :title, :content
  meta_attributes :created_at, :updated_at
  has_one :user
  has_one :author, attr: :user, resource: 'UserResource'
  has_many :replies, resource: 'PostResource'
  has_one :parent_post, resource: 'PostResource'
  has_many :tags
end

class TagResource < JPie::Resource
  attributes :name
  meta_attributes :created_at, :updated_at
  has_many :posts
  has_many :tagged_posts, attr: :posts, resource: 'PostResource'
end

# STI Resource classes for testing
class VehicleResource < JPie::Resource
  attributes :name, :brand, :year
  meta_attributes :created_at, :updated_at
end

class CarResource < VehicleResource
  attributes :engine_size
end
