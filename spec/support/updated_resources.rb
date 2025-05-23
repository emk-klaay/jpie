# frozen_string_literal: true

# Updated resource classes that hide join tables while maintaining existing functionality
class UpdatedPostResource < JPie::Resource
  model Post
  type 'posts'

  attributes :title, :content
  meta_attributes :created_at, :updated_at
  has_one :user
  has_many :comments, resource: 'UpdatedCommentResource'
  has_many :tags, resource: 'UpdatedTagResource'
  # Removed: has_many :taggings - join table is hidden from API
end

class UpdatedCommentResource < JPie::Resource
  model Comment
  type 'comments'

  attributes :content
  meta_attributes :created_at, :updated_at
  has_one :user
  has_one :post, resource: 'UpdatedPostResource'
  has_one :parent_comment, resource: 'UpdatedCommentResource'
  has_many :likes
  has_many :replies, resource: 'UpdatedCommentResource'
  has_many :tags, resource: 'UpdatedTagResource'
  # Removed: has_many :taggings - join table is hidden from API
end

class UpdatedTagResource < JPie::Resource
  model Tag
  type 'tags'

  attributes :name
  meta_attributes :created_at, :updated_at

  # Clean API: direct relationships to tagged resources
  has_many :posts, resource: 'UpdatedPostResource'
  has_many :comments, resource: 'UpdatedCommentResource'
  # Removed: has_many :taggings - join table is hidden from API

  # Optional: provide semantic names if preferred
  # has_many :tagged_posts, attr: :posts, resource: 'UpdatedPostResource'
  # has_many :tagged_comments, attr: :comments, resource: 'UpdatedCommentResource'
end
