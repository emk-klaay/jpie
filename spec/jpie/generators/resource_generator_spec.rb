# frozen_string_literal: true

require 'spec_helper'
require 'rails/generators/test_case'
require 'jpie/generators/resource_generator'

RSpec.describe JPie::Generators::ResourceGenerator, type: :generator do
  include GeneratorHelper

  let(:destination) { File.expand_path('../../tmp/generators', __dir__) }

  before do
    prepare_destination
  end

  describe 'semantic syntax' do
    it 'generates resource with explicit attribute prefixes' do
      run_generator %w[User attribute:name attribute:email meta:created_at]

      expect(destination_file_exists?('app/resources/user_resource.rb')).to be true

      content = destination_file_content('app/resources/user_resource.rb')
      expect(content).to include('class UserResource < JPie::Resource')
      expect(content).to include('attributes :name, :email')
      expect(content).to include('meta_attributes :created_at')
      expect(content).not_to include('model User') # Should use automatic inference
    end

    it 'generates relationships with semantic syntax' do
      run_generator %w[User attribute:name relationship:has_many:posts relationship:has_one:profile]

      content = destination_file_content('app/resources/user_resource.rb')
      expect(content).to include('attributes :name')
      expect(content).to include('has_many :posts')
      expect(content).to include('has_one :profile')
    end

    it 'supports shorthand relationship syntax' do
      run_generator %w[User attribute:name has_many:posts has_one:profile belongs_to:company]

      content = destination_file_content('app/resources/user_resource.rb')
      expect(content).to include('attributes :name')
      expect(content).to include('has_many :posts')
      expect(content).to include('has_one :profile')
      expect(content).to include('belongs_to :company')
    end

    it 'handles mixed semantic and plain field names' do
      run_generator %w[User attribute:name email meta:created_at updated_at]

      content = destination_file_content('app/resources/user_resource.rb')
      expect(content).to include('attributes :name, :email')
      expect(content).to include('meta_attributes :created_at, :updated_at')
    end
  end

  describe 'backward compatibility' do
    it 'generates a basic resource with legacy field:type syntax' do
      run_generator %w[User name:string email:string]

      expect(destination_file_exists?('app/resources/user_resource.rb')).to be true

      content = destination_file_content('app/resources/user_resource.rb')
      expect(content).to include('class UserResource < JPie::Resource')
      expect(content).to include('attributes :name, :email')
      expect(content).not_to include('model User') # Should use automatic inference
    end

    it 'automatically detects meta attributes from common names in legacy syntax' do
      run_generator %w[User name:string created_at:datetime updated_at:datetime]

      content = destination_file_content('app/resources/user_resource.rb')
      expect(content).to include('attributes :name')
      expect(content).to include('meta_attributes :created_at, :updated_at')
    end
  end

  describe 'model specification' do
    it 'generates explicit model declaration when different model specified' do
      run_generator %w[User attribute:name --model=Person]

      content = destination_file_content('app/resources/user_resource.rb')
      expect(content).to include('model Person')
    end
  end

  describe 'empty resource generation' do
    it 'generates helpful comments when no fields specified' do
      run_generator %w[User]

      content = destination_file_content('app/resources/user_resource.rb')
      expect(content).to include('# Define your attributes here:')
      expect(content).to include('# Define your meta attributes here:')
      expect(content).to include('# Define your relationships here:')
    end
  end

  describe 'comprehensive resource generation with new syntax' do
    it 'generates a fully featured resource using semantic syntax' do
      run_generator [
        'Post',
        'attribute:title',
        'attribute:content',
        'meta:published_at',
        'meta:created_at',
        'meta:updated_at',
        'has_one:author',
        'has_many:comments',
        'has_many:tags',
        '--model=Article'
      ]

      content = destination_file_content('app/resources/post_resource.rb')

      expect(content).to include('class PostResource < JPie::Resource')
      expect(content).to include('model Article')
      expect(content).to include('attributes :title, :content')
      expect(content).to include('meta_attributes :published_at, :created_at, :updated_at')
      expect(content).to include('has_one :author')
      expect(content).to include('has_many :comments')
      expect(content).to include('has_many :tags')
    end
  end
end
