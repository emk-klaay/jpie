# frozen_string_literal: true

require 'active_record'
require 'sqlite3'

# Set up in-memory SQLite3 database
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: ':memory:'
)

# Define the schema with minimal models that cover all JPie functionality
ActiveRecord::Schema.define do
  # Core model for basic functionality
  create_table :users do |t|
    t.string :name
    t.string :email
    t.timestamps
  end

  # Model for has_many relationships and polymorphic commentable
  create_table :posts do |t|
    t.string :title
    t.text :content
    t.integer :user_id
    t.integer :parent_post_id # For self-referencing relationships (replaces comment nesting)
    t.timestamps
  end

  # Model for many-to-many through associations (tags can belong to posts)
  create_table :tags do |t|
    t.string :name
    t.timestamps
  end

  # Join table for polymorphic many-to-many relationships
  create_table :taggings do |t|
    t.integer :tag_id
    t.references :taggable, polymorphic: true, null: false
    t.timestamps
  end

  # STI table for testing Single Table Inheritance
  create_table :vehicles do |t|
    t.string :type
    t.string :name
    t.string :brand
    t.integer :year
    t.integer :engine_size # specific to cars
    t.timestamps
  end
end

# Define ActiveRecord models with all necessary associations
class User < ActiveRecord::Base
  validates :name, presence: true
  has_many :posts, dependent: :destroy
end

class Post < ActiveRecord::Base
  belongs_to :user
  validates :title, presence: true
  has_many :replies, class_name: 'Post', foreign_key: 'parent_post_id', dependent: :destroy
  belongs_to :parent_post, class_name: 'Post', optional: true
  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  alias author user
  alias author= user=
end

class Tag < ActiveRecord::Base
  validates :name, presence: true
  has_many :taggings, dependent: :destroy
  has_many :posts, through: :taggings, source: :taggable, source_type: 'Post'
end

class Tagging < ActiveRecord::Base
  belongs_to :tag
  belongs_to :taggable, polymorphic: true
end

# STI models for testing Single Table Inheritance
class Vehicle < ActiveRecord::Base
  validates :name, presence: true
  validates :brand, presence: true
  validates :year, presence: true
end

class Car < Vehicle
  validates :engine_size, presence: true
end
