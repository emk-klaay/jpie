# frozen_string_literal: true

# Clean resource classes that don't expose join tables
class CleanPostResource < JPie::Resource
  model Post
  type 'posts'

  attributes :title, :content
  meta_attributes :created_at, :updated_at
  has_one :user
  has_many :comments, resource: 'CleanCommentResource'
  has_many :tags, resource: 'CleanTagResource'
  # NOTE: No has_many :taggings - join table is hidden
end

class CleanCommentResource < JPie::Resource
  model Comment
  type 'comments'

  attributes :content
  meta_attributes :created_at, :updated_at
  has_one :user
  has_one :post, resource: 'CleanPostResource'
  has_one :parent_comment, resource: 'CleanCommentResource'
  has_many :likes
  has_many :replies, resource: 'CleanCommentResource'
  has_many :tags, resource: 'CleanTagResource'
  # NOTE: No has_many :taggings - join table is hidden
end

class CleanTagResource < JPie::Resource
  model Tag
  type 'tags'

  attributes :name
  meta_attributes :created_at, :updated_at

  # Provide semantic names instead of exposing the join table
  has_many :tagged_posts, attr: :posts, resource: 'CleanPostResource'
  has_many :tagged_comments, attr: :comments, resource: 'CleanCommentResource'

  # Alternative: if you want to use the same names as ActiveRecord
  has_many :posts, resource: 'CleanPostResource'
  has_many :comments, resource: 'CleanCommentResource'

  # NOTE: No has_many :taggings - join table is hidden
end
