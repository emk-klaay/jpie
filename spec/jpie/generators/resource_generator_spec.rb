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

  describe 'basic resource generation' do
    it 'generates a basic resource with attributes' do
      run_generator %w[User name:string email:string]

      expect(destination_file_exists?('app/resources/user_resource.rb')).to be true

      content = destination_file_content('app/resources/user_resource.rb')
      expect(content).to include('class UserResource < JPie::Resource')
      expect(content).to include('attributes :name, :email')
      expect(content).not_to include('model User') # Should use automatic inference
    end
  end

  describe 'model specification' do
    it 'generates explicit model declaration when different model specified' do
      run_generator %w[User name:string --model=Person]

      content = destination_file_content('app/resources/user_resource.rb')
      expect(content).to include('model Person')
    end
  end

  describe 'meta attributes' do
    it 'automatically detects meta attributes from common names' do
      run_generator %w[User name:string created_at:datetime updated_at:datetime]

      content = destination_file_content('app/resources/user_resource.rb')
      expect(content).to include('attributes :name')
      expect(content).to include('meta_attributes :created_at, :updated_at')
    end
  end

  describe 'relationships' do
    it 'generates relationships from CLI options' do
      run_generator ['User', 'name:string', '--relationships=has_many:posts,has_one:profile']

      content = destination_file_content('app/resources/user_resource.rb')
      expect(content).to include('has_many :posts')
      expect(content).to include('has_one :profile')
    end
  end

  describe 'empty resource generation' do
    it 'generates helpful comments when no attributes specified' do
      run_generator %w[User]

      content = destination_file_content('app/resources/user_resource.rb')
      expect(content).to include('# Define your attributes here:')
      expect(content).to include('# Define your meta attributes here:')
      expect(content).to include('# Define your relationships here:')
    end
  end

  describe 'comprehensive resource generation' do
    it 'generates a fully featured resource' do
      run_generator [
        'Post',
        'title:string',
        'content:text',
        'published_at:datetime',
        '--meta-attributes=created_at,updated_at',
        '--relationships=has_one:author,has_many:comments,has_many:tags',
        '--model=Article'
      ]

      content = destination_file_content('app/resources/post_resource.rb')

      expect(content).to include('class PostResource < JPie::Resource')
      expect(content).to include('model Article')
      expect(content).to include('attributes :title, :content')
      expect(content).to include('meta_attributes :created_at, :updated_at, :published_at')
      expect(content).to include('has_one :author')
      expect(content).to include('has_many :comments')
      expect(content).to include('has_many :tags')
    end
  end
end
