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

  create_table :articles do |t|
    t.string :title
    t.text :body
    t.integer :user_id
    t.timestamps
  end

  create_table :videos do |t|
    t.string :title
    t.string :url
    t.integer :user_id
    t.timestamps
  end

  create_table :comments do |t|
    t.text :content
    t.integer :user_id
    t.integer :post_id
    t.references :commentable, polymorphic: true, null: true
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

  create_table :taggings do |t|
    t.integer :tag_id
    t.references :taggable, polymorphic: true, null: false
    t.timestamps
  end

  # STI table for vehicles
  create_table :vehicles do |t|
    t.string :type
    t.string :name
    t.string :brand
    t.integer :year
    t.integer :engine_size # specific to cars
    t.integer :cargo_capacity # specific to trucks
    t.timestamps
  end
end

# Define ActiveRecord models
class User < ActiveRecord::Base
  validates :name, presence: true
  has_many :posts, dependent: :destroy
  has_many :articles, dependent: :destroy
  has_many :videos, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :likes, dependent: :destroy
end

class Post < ActiveRecord::Base
  belongs_to :user
  validates :title, presence: true
  has_many :comments, dependent: :destroy
  has_many :polymorphic_comments, as: :commentable, class_name: 'Comment', dependent: :destroy
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  alias_method :author, :user
  alias_method :author=, :user=
end

class Article < ActiveRecord::Base
  belongs_to :user
  validates :title, presence: true
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  alias_method :author, :user
  alias_method :author=, :user=
end

class Video < ActiveRecord::Base
  belongs_to :user
  validates :title, presence: true
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  alias_method :author, :user
  alias_method :author=, :user=
end

class Comment < ActiveRecord::Base
  belongs_to :user
  belongs_to :post, optional: true
  belongs_to :commentable, polymorphic: true, optional: true
  belongs_to :parent_comment, class_name: 'Comment', optional: true
  validates :content, presence: true
  has_many :likes, dependent: :destroy
  has_many :replies, class_name: 'Comment', foreign_key: 'parent_comment_id', dependent: :destroy
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  alias_method :author, :user
  alias_method :author=, :user=
end

class Like < ActiveRecord::Base
  belongs_to :user
  belongs_to :comment
end

class Tag < ActiveRecord::Base
  validates :name, presence: true
  has_many :taggings, dependent: :destroy
  has_many :posts, through: :taggings, source: :taggable, source_type: 'Post'
  has_many :comments, through: :taggings, source: :taggable, source_type: 'Comment'
end

class Tagging < ActiveRecord::Base
  belongs_to :tag
  belongs_to :taggable, polymorphic: true
end

# STI models for testing
class Vehicle < ActiveRecord::Base
  validates :name, presence: true
  validates :brand, presence: true
  validates :year, presence: true
end

class Car < Vehicle
  validates :engine_size, presence: true
end

class Truck < Vehicle
  validates :cargo_capacity, presence: true
end
