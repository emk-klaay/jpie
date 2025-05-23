# frozen_string_literal: true

# Resource classes for testing
class UserResource < JPie::Resource
  model User
  attributes :name, :email, :created_at, :updated_at
end

class PostResource < JPie::Resource
  model Post
  attributes :title, :content, :user_id, :created_at, :updated_at
end
