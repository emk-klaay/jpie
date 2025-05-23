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
end

# Define ActiveRecord models
class User < ActiveRecord::Base
  validates :name, presence: true
  has_many :posts, dependent: :destroy
end

class Post < ActiveRecord::Base
  belongs_to :user
  validates :title, presence: true
end
