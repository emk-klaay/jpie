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

RSpec.describe JPie::Serializer do
  let(:user) { User.create!(name: 'John Doe', email: 'john@example.com') }
  let(:first_post) { Post.create!(title: 'First Post', content: 'Content 1', user: user) }
  let(:second_post) { Post.create!(title: 'Second Post', content: 'Content 2', user: user) }

  describe '#serialize with include parameter' do
    let(:serializer) { described_class.new(PostResource) }

    it 'serializes without includes when no includes specified' do
      result = serializer.serialize(first_post)

      expect(result).to have_key(:data)
      expect(result).not_to have_key(:included)
      expect(result[:data][:id]).to eq(first_post.id.to_s)
      expect(result[:data][:type]).to eq('posts')
    end

    describe 'when user include is specified' do
      let(:result) { serializer.serialize(first_post, {}, includes: ['user']) }

      it 'includes the data and included sections' do
        expect(result).to have_key(:data)
        expect(result).to have_key(:included)
        expect(result[:included]).to be_an(Array)
        expect(result[:included].length).to eq(1)
      end

      it 'includes correct user data in included section' do
        included_user = result[:included].first
        expect(included_user[:id]).to eq(user.id.to_s)
        expect(included_user[:type]).to eq('users')
        expect(included_user[:attributes]['name']).to eq('John Doe')
      end
    end

    describe 'with multiple posts' do
      let(:result) { serializer.serialize([first_post, second_post], {}, includes: ['user']) }

      it 'includes data for all posts' do
        expect(result).to have_key(:data)
        expect(result).to have_key(:included)
        expect(result[:data]).to be_an(Array)
        expect(result[:data].length).to eq(2)
      end

      it 'deduplicates the same user in included section' do
        # Should only include the user once even though both posts reference the same user
        expect(result[:included].length).to eq(1)

        included_user = result[:included].first
        expect(included_user[:id]).to eq(user.id.to_s)
        expect(included_user[:type]).to eq('users')
      end
    end

    it 'handles non-existent relationships gracefully' do
      result = serializer.serialize(first_post, {}, includes: ['nonexistent'])

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

    it 'parses multiple include parameters from query string' do
      controller.params = { include: 'user,author' }
      includes = controller.send(:parse_include_params)

      expect(includes).to eq(%w[user author])
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

    describe 'when include=user parameter is provided' do
      it 'includes post data and related user data with correct content type' do
        user = User.create!(name: 'John Doe', email: 'john@example.com')
        post = Post.create!(title: 'Test Post', content: 'Content', user: user)

        controller.params = { id: post.id.to_s, include: 'user' }
        controller.show
        response_data = controller.last_render[:json]

        # Verify post data
        expect(response_data).to have_key(:data)
        expect(response_data[:data][:id]).to eq(post.id.to_s)
        expect(response_data[:data][:type]).to eq('posts')

        # Verify included user data
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
