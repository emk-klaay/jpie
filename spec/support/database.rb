# frozen_string_literal: true

require 'active_record'
require 'sqlite3'

# Set up in-memory SQLite3 database
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

# Define the schema
ActiveRecord::Schema.define do
  create_table :users do |t|
    t.string :name
    t.string :email
    t.timestamps
  end

  create_table :posts do |t|
    t.string :title
    t.text :content
    t.integer :user_id
    t.timestamps
  end

  create_table :comments do |t|
    t.text :content
    t.integer :user_id
    t.integer :post_id
    t.integer :parent_comment_id # For nested comments/replies
    t.timestamps
  end

  create_table :likes do |t|
    t.integer :user_id
    t.integer :comment_id
    t.timestamps
  end

  create_table :tags do |t|
    t.string :name
    t.timestamps
  end

  create_table :post_tags do |t|
    t.integer :post_id
    t.integer :tag_id
    t.timestamps
  end
end

# Define ActiveRecord models
class User < ActiveRecord::Base
  validates :name, presence: true
  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy
end

class Post < ActiveRecord::Base
  belongs_to :user
  validates :title, presence: true
  has_many :comments, dependent: :destroy
  has_many :post_tags, dependent: :destroy
  has_many :tags, through: :post_tags
end

class Comment < ActiveRecord::Base
  belongs_to :user
  belongs_to :post
  belongs_to :parent_comment, class_name: 'Comment', optional: true
  validates :content, presence: true
  has_many :likes, dependent: :destroy
  has_many :replies, class_name: 'Comment', foreign_key: 'parent_comment_id', dependent: :destroy
end

class Like < ActiveRecord::Base
  belongs_to :user
  belongs_to :comment
end

class Tag < ActiveRecord::Base
  validates :name, presence: true
  has_many :post_tags, dependent: :destroy
  has_many :posts, through: :post_tags
end

class PostTag < ActiveRecord::Base
  belongs_to :post
  belongs_to :tag
end
