# frozen_string_literal: true

require 'spec_helper'

# Define ApplicationController for tests
class ApplicationController
  def self.rescue_from(exception_class, with: nil)
    # Mock implementation for testing
  end

  def head(status)
    # Mock implementation
  end
end

RSpec.describe 'JSON:API Include Parameter' do
  let(:user) { User.create!(name: 'John Doe', email: 'john@example.com') }
  let(:post1) { Post.create!(title: 'First Post', content: 'Content 1', user: user) }
  let(:post2) { Post.create!(title: 'Second Post', content: 'Content 2', user: user) }

  describe 'Serializer include support' do
    let(:serializer) { JPie::Serializer.new(PostResource) }

    it 'serializes without includes when no includes specified' do
      result = serializer.serialize(post1)
      
      expect(result).to have_key(:data)
      expect(result).not_to have_key(:included)
      expect(result[:data][:id]).to eq(post1.id.to_s)
      expect(result[:data][:type]).to eq('posts')
    end

    it 'includes related user data when user include is specified' do
      result = serializer.serialize(post1, {}, includes: ['user'])
      
      expect(result).to have_key(:data)
      expect(result).to have_key(:included)
      expect(result[:included]).to be_an(Array)
      expect(result[:included].length).to eq(1)
      
      included_user = result[:included].first
      expect(included_user[:id]).to eq(user.id.to_s)
      expect(included_user[:type]).to eq('users')
      expect(included_user[:attributes]['name']).to eq('John Doe')
    end

    it 'includes related data for multiple posts' do
      result = serializer.serialize([post1, post2], {}, includes: ['user'])
      
      expect(result).to have_key(:data)
      expect(result).to have_key(:included)
      expect(result[:data]).to be_an(Array)
      expect(result[:data].length).to eq(2)
      
      # Should only include the user once even though both posts reference the same user
      expect(result[:included].length).to eq(1)
      
      included_user = result[:included].first
      expect(included_user[:id]).to eq(user.id.to_s)
      expect(included_user[:type]).to eq('users')
    end

    it 'handles non-existent relationships gracefully' do
      result = serializer.serialize(post1, {}, includes: ['nonexistent'])
      
      expect(result).to have_key(:data)
      expect(result).not_to have_key(:included)
    end
  end

  describe 'Controller include parameter parsing' do
    let(:controller_class) do
      Class.new(ApplicationController) do
        include JPie::Controller

        def self.name
          'PostsController'
        end

        attr_accessor :params, :request, :response

        def initialize
          @params = {}
          @request = MockRequest.new
          @response = MockResponse.new
        end

        def render(options = {})
          @last_render = options
        end

        def action_name
          'index'
        end

        attr_reader :last_render
      end
    end

    let(:controller) { controller_class.new }

    before do
      # Mock classes for controller test
      stub_const('MockRequest', Class.new do
        def body
          MockBody.new
        end
      end)

      stub_const('MockBody', Class.new do
        def read
          '{}'
        end
      end)

      stub_const('MockResponse', Class.new)
    end

    it 'parses include parameter from query string' do
      controller.params = { include: 'user,author' }
      includes = controller.send(:parse_include_params)
      
      expect(includes).to eq(['user', 'author'])
    end

    it 'returns empty array when no include parameter' do
      controller.params = {}
      includes = controller.send(:parse_include_params)
      
      expect(includes).to eq([])
    end

    it 'handles single include parameter' do
      controller.params = { include: 'user' }
      includes = controller.send(:parse_include_params)
      
      expect(includes).to eq(['user'])
    end
  end

  describe 'End-to-end integration' do
    let(:controller_class) do
      Class.new(ApplicationController) do
        include JPie::Controller

        def self.name
          'PostsController'
        end

        attr_accessor :params, :request, :response

        def initialize
          @params = {}
          @request = MockRequest.new
          @response = MockResponse.new
        end

        def render(options = {})
          @last_render = options
        end

        def action_name
          'show'
        end

        attr_reader :last_render
      end
    end

    let(:controller) { controller_class.new }

    before do
      # Mock classes for controller test
      stub_const('MockRequest', Class.new do
        def body
          MockBody.new
        end
      end)

      stub_const('MockBody', Class.new do
        def read
          '{}'
        end
      end)

      stub_const('MockResponse', Class.new)
    end

    it 'renders post with included user when include=user parameter is provided' do
      # Set up data
      user = User.create!(name: 'John Doe', email: 'john@example.com')
      post = Post.create!(title: 'Test Post', content: 'Content', user: user)

      # Simulate controller request with include parameter
      controller.params = { id: post.id.to_s, include: 'user' }
      controller.show

      # Verify the response includes the post data
      response_data = controller.last_render[:json]
      expect(response_data).to have_key(:data)
      expect(response_data[:data][:id]).to eq(post.id.to_s)
      expect(response_data[:data][:type]).to eq('posts')

      # Verify the response includes the related user data
      expect(response_data).to have_key(:included)
      expect(response_data[:included]).to be_an(Array)
      expect(response_data[:included].length).to eq(1)

      included_user = response_data[:included].first
      expect(included_user[:id]).to eq(user.id.to_s)
      expect(included_user[:type]).to eq('users')
      expect(included_user[:attributes]['name']).to eq('John Doe')
      expect(included_user[:attributes]['email']).to eq('john@example.com')

      # Verify content type
      expect(controller.last_render[:content_type]).to eq('application/vnd.api+json')
    end

    it 'renders post without included data when no include parameter is provided' do
      # Set up data
      user = User.create!(name: 'John Doe', email: 'john@example.com')
      post = Post.create!(title: 'Test Post', content: 'Content', user: user)

      # Simulate controller request without include parameter
      controller.params = { id: post.id.to_s }
      controller.show

      # Verify the response includes the post data
      response_data = controller.last_render[:json]
      expect(response_data).to have_key(:data)
      expect(response_data[:data][:id]).to eq(post.id.to_s)
      expect(response_data[:data][:type]).to eq('posts')

      # Verify the response does not include related data
      expect(response_data).not_to have_key(:included)
    end
  end
end 