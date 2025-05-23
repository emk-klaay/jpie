# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JPie do
  describe 'Integration: Controller Include Parameters for has_many relationships' do
    let(:controller_class) do
      Class.new(ApplicationController) do
        include JPie::Controller

        def self.name
          'UsersController'
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
    let(:user) { User.create!(name: 'John Doe', email: 'john@example.com') }
    let!(:first_post) { Post.create!(title: 'First Post', content: 'Content 1', user: user) }
    let!(:second_post) { Post.create!(title: 'Second Post', content: 'Content 2', user: user) }

    before do
      # Mock classes for controller test
      stub_const('ApplicationController', Class.new do
        def self.rescue_from(exception_class, with: nil)
          # Mock implementation for testing
        end

        def head(status)
          # Mock implementation
        end
      end)

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

    describe 'GET /users/:id?include=posts' do
      it 'includes posts in the response when include=posts is specified', :aggregate_failures do
        controller.params = { id: user.id.to_s, include: 'posts' }
        controller.show

        result = controller.last_render[:json]

        expect(result).to have_key(:included)
        expect(result[:included]).to be_an(Array)
        expect(result[:included].length).to eq(2)
      end

      it 'includes correct user data in main response', :aggregate_failures do
        controller.params = { id: user.id.to_s, include: 'posts' }
        controller.show

        result = controller.last_render[:json]

        expect(result[:data][:id]).to eq(user.id.to_s)
        expect(result[:data][:type]).to eq('users')
        expect(result[:data][:attributes]['name']).to eq('John Doe')
      end

      it 'includes both posts in included section' do
        controller.params = { id: user.id.to_s, include: 'posts' }
        controller.show

        result = controller.last_render[:json]

        post_ids = result[:included].map { |item| item[:id] }
        expect(post_ids).to contain_exactly(first_post.id.to_s, second_post.id.to_s)
      end

      it 'includes correct post structure in included section', :aggregate_failures do
        controller.params = { id: user.id.to_s, include: 'posts' }
        controller.show

        result = controller.last_render[:json]

        result[:included].each do |included_item|
          expect(included_item[:type]).to eq('posts')
          expect(included_item[:attributes]).to have_key('title')
          expect(included_item[:attributes]).to have_key('content')
        end
      end

      it 'returns correct response metadata', :aggregate_failures do
        controller.params = { id: user.id.to_s, include: 'posts' }
        controller.show

        expect(controller.last_render[:status]).to eq(:ok)
        expect(controller.last_render[:content_type]).to eq('application/vnd.api+json')
      end

      it 'includes correct attributes for included posts', :aggregate_failures do
        controller.params = { id: user.id.to_s, include: 'posts' }
        controller.show

        result = controller.last_render[:json]

        result[:included].each do |included_post|
          expect(included_post[:type]).to eq('posts')

          expected_attributes = %w[title content]
          actual_attributes = included_post[:attributes].keys

          expect(actual_attributes).to include(*expected_attributes)
        end
      end

      it 'includes correct attribute values for included posts', :aggregate_failures do
        controller.params = { id: user.id.to_s, include: 'posts' }
        controller.show

        result = controller.last_render[:json]

        result[:included].each do |included_post|
          expect(included_post[:attributes]['title']).to be_a(String)
          expect(included_post[:attributes]['content']).to be_a(String)
        end
      end

      it 'includes meta attributes for included posts', :aggregate_failures do
        controller.params = { id: user.id.to_s, include: 'posts' }
        controller.show

        result = controller.last_render[:json]

        result[:included].each do |included_post|
          expect(included_post).to have_key(:meta)
          expect(included_post[:meta]).to have_key('created_at')
          expect(included_post[:meta]).to have_key('updated_at')
        end
      end

      it 'formats timestamps correctly for included posts', :aggregate_failures do
        controller.params = { id: user.id.to_s, include: 'posts' }
        controller.show

        result = controller.last_render[:json]

        result[:included].each do |included_post|
          expect(included_post[:meta]['created_at']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
          expect(included_post[:meta]['updated_at']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
        end
      end

      it 'does not include posts when no include parameter is specified' do
        controller.params = { id: user.id.to_s }
        controller.show

        result = controller.last_render[:json]

        expect(result).not_to have_key(:included)
      end

      it 'includes main user data when no include parameter specified', :aggregate_failures do
        controller.params = { id: user.id.to_s }
        controller.show

        result = controller.last_render[:json]

        expect(result[:data][:id]).to eq(user.id.to_s)
        expect(result[:data][:type]).to eq('users')
      end

      it 'handles multiple include parameters correctly', :aggregate_failures do
        controller.params = { id: user.id.to_s, include: 'posts,nonexistent' }
        controller.show

        result = controller.last_render[:json]

        expect(result).to have_key(:included)
        expect(result[:included].length).to eq(2)
      end

      it 'ignores nonexistent relationships in multiple includes' do
        controller.params = { id: user.id.to_s, include: 'posts,nonexistent' }
        controller.show

        result = controller.last_render[:json]

        result[:included].each do |included_item|
          expect(included_item[:type]).to eq('posts')
        end
      end
    end

    describe 'GET /users (index) with include=posts' do
      let(:second_user) { User.create!(name: 'Jane Doe', email: 'jane@example.com') }
      let!(:third_post) { Post.create!(title: 'Third Post', content: 'Content 3', user: second_user) }

      it 'includes posts for all users in index response', :aggregate_failures do
        controller.params = { include: 'posts' }
        controller.index

        result = controller.last_render[:json]

        expect(result).to have_key(:included)
        expect(result[:included]).to be_an(Array)
        expect(result[:included].length).to eq(3) # All 3 posts
      end

      it 'returns correct users data structure', :aggregate_failures do
        controller.params = { include: 'posts' }
        controller.index

        result = controller.last_render[:json]

        expect(result[:data]).to be_an(Array)
        expect(result[:data].length).to eq(2)
      end

      it 'includes all posts in included section', :aggregate_failures do
        controller.params = { include: 'posts' }
        controller.index

        result = controller.last_render[:json]

        result[:included].each do |included_item|
          expect(included_item[:type]).to eq('posts')
        end

        post_ids = result[:included].map { |item| item[:id] }
        expect(post_ids).to contain_exactly(first_post.id.to_s, second_post.id.to_s, third_post.id.to_s)
      end

      it 'includes correct attributes for all posts in index', :aggregate_failures do
        controller.params = { include: 'posts' }
        controller.index

        result = controller.last_render[:json]

        expect(result[:included].length).to eq(3)

        result[:included].each do |included_post|
          expect(included_post[:type]).to eq('posts')

          expected_attributes = %w[title content]
          actual_attributes = included_post[:attributes].keys

          expect(actual_attributes).to include(*expected_attributes)
        end
      end

      it 'includes correct attribute values for all posts in index', :aggregate_failures do
        controller.params = { include: 'posts' }
        controller.index

        result = controller.last_render[:json]

        result[:included].each do |included_post|
          expect(included_post[:attributes]['title']).to be_a(String)
          expect(included_post[:attributes]['content']).to be_a(String)
        end
      end

      it 'includes meta attributes for all posts in index', :aggregate_failures do
        controller.params = { include: 'posts' }
        controller.index

        result = controller.last_render[:json]

        result[:included].each do |included_post|
          expect(included_post).to have_key(:meta)
          expect(included_post[:meta]).to have_key('created_at')
          expect(included_post[:meta]).to have_key('updated_at')
        end
      end
    end

    describe 'Reverse relationship: POST with include=user' do
      let(:posts_controller_class) do
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

      let(:posts_controller) { posts_controller_class.new }

      it 'includes all defined attributes for included user', :aggregate_failures do
        posts_controller.params = { id: first_post.id.to_s, include: 'user' }
        posts_controller.show

        result = posts_controller.last_render[:json]

        # Verify main post data
        expect(result[:data][:id]).to eq(first_post.id.to_s)
        expect(result[:data][:type]).to eq('posts')

        # Verify included user data structure
        expect(result).to have_key(:included)
        expect(result[:included]).to be_an(Array)
        expect(result[:included].length).to eq(1)

        included_user = result[:included].first
        expect(included_user[:type]).to eq('users')
        expect(included_user[:id]).to eq(user.id.to_s)
      end

      it 'includes correct user attributes and meta data', :aggregate_failures do
        posts_controller.params = { id: first_post.id.to_s, include: 'user' }
        posts_controller.show

        result = posts_controller.last_render[:json]
        included_user = result[:included].first

        # UserResource defines: name, email (attributes) + created_at, updated_at (meta)
        expected_attributes = %w[name email]
        actual_attributes = included_user[:attributes].keys

        expect(actual_attributes).to include(*expected_attributes)

        # Verify attribute values
        expect(included_user[:attributes]['name']).to eq('John Doe')
        expect(included_user[:attributes]['email']).to eq('john@example.com')

        # Verify meta attributes
        expect(included_user).to have_key(:meta)
        expect(included_user[:meta]).to have_key('created_at')
        expect(included_user[:meta]).to have_key('updated_at')

        # Verify timestamps are in ISO8601 format
        expect(included_user[:meta]['created_at']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
        expect(included_user[:meta]['updated_at']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      end
    end
  end
end
