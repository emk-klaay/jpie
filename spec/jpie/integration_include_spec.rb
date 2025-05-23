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

        # Verify main user data
        expect(result[:data][:id]).to eq(user.id.to_s)
        expect(result[:data][:type]).to eq('users')
        expect(result[:data][:attributes]['name']).to eq('John Doe')

        # Verify included posts data
        expect(result).to have_key(:included)
        expect(result[:included]).to be_an(Array)
        expect(result[:included].length).to eq(2)

        # Check that both posts are included
        post_ids = result[:included].map { |item| item[:id] }
        expect(post_ids).to contain_exactly(first_post.id.to_s, second_post.id.to_s)

        # Check post details
        result[:included].each do |included_item|
          expect(included_item[:type]).to eq('posts')
          expect(included_item[:attributes]).to have_key('title')
          expect(included_item[:attributes]).to have_key('content')
        end

        # Verify response metadata
        expect(controller.last_render[:status]).to eq(:ok)
        expect(controller.last_render[:content_type]).to eq('application/vnd.api+json')
      end

      it 'does not include posts when no include parameter is specified', :aggregate_failures do
        controller.params = { id: user.id.to_s }
        controller.show

        result = controller.last_render[:json]

        # Verify main user data is present
        expect(result[:data][:id]).to eq(user.id.to_s)
        expect(result[:data][:type]).to eq('users')

        # Verify no included data
        expect(result).not_to have_key(:included)
      end

      it 'handles multiple include parameters correctly', :aggregate_failures do
        controller.params = { id: user.id.to_s, include: 'posts,nonexistent' }
        controller.show

        result = controller.last_render[:json]

        # Should include posts despite nonexistent relationship
        expect(result).to have_key(:included)
        expect(result[:included].length).to eq(2)

        # All included items should be posts (nonexistent is ignored)
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

        # Verify users data
        expect(result[:data]).to be_an(Array)
        expect(result[:data].length).to eq(2)

        # Verify included posts data
        expect(result).to have_key(:included)
        expect(result[:included]).to be_an(Array)
        expect(result[:included].length).to eq(3) # All 3 posts

        # All included items should be posts
        result[:included].each do |included_item|
          expect(included_item[:type]).to eq('posts')
        end

        # Check that all post IDs are present
        post_ids = result[:included].map { |item| item[:id] }
        expect(post_ids).to contain_exactly(first_post.id.to_s, second_post.id.to_s, third_post.id.to_s)
      end
    end
  end
end
