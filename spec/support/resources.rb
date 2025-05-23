# frozen_string_literal: true

# Resource classes for testing
class UserResource < JPie::Resource
  model User
  attributes :name, :email, :created_at, :updated_at
  relationship :posts, resource: 'PostResource'
end

class PostResource < JPie::Resource
  model Post
  attributes :title, :content, :created_at, :updated_at
  relationship :user, resource: 'UserResource'
end
