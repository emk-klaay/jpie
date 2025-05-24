# frozen_string_literal: true

class UserResource < JPie::Resource
  model Person

  attributes :name

  # Define your meta attributes here:
  # meta_attributes :created_at, :updated_at

  # Define your relationships here:
  # has_many :posts
  # has_one :user
end
