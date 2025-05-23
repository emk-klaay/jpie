# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Nested Includes Integration' do
  # Set up test data with proper relationships
  let!(:user1) { User.create!(name: 'Alice Smith', email: 'alice@example.com') }
  let!(:user2) { User.create!(name: 'Bob Johnson', email: 'bob@example.com') }

  let!(:post1) { Post.create!(title: 'First Post', content: 'Content of first post', user: user1) }
  let!(:post2) { Post.create!(title: 'Second Post', content: 'Content of second post', user: user2) }
  let!(:post3) { Post.create!(title: 'Third Post', content: 'Content of third post', user: user1) }

  let!(:comment1) { Comment.create!(content: 'Great post!', user: user2, post: post1) }
  let!(:comment2) { Comment.create!(content: 'I agree!', user: user1, post: post1) }
  let!(:comment3) { Comment.create!(content: 'Interesting perspective', user: user1, post: post2) }
  let!(:comment4) { Comment.create!(content: 'Thanks for sharing', user: user2, post: post3) }

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

    stub_const('BaseController', Class.new do
      def self.rescue_from(exception_class, with: nil)
        # Mock implementation for testing
      end

      def head(status)
        # Mock implementation
      end
    end)
  end

  describe 'GET /posts?include=user,user.comments' do
    let(:controller_class) do
      Class.new(BaseController) do
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

    context 'when requesting all posts with nested user comments' do
      before do
        controller.params = { include: 'user,user.comments' }
        controller.index
      end

      let(:response_data) { controller.last_render[:json] }

      it 'returns JSON:API compliant structure', :aggregate_failures do
        expect(response_data).to have_key(:data)
        expect(response_data).to have_key(:included)
        expect(controller.last_render[:content_type]).to eq('application/vnd.api+json')
      end

      it 'includes all posts in the main data section', :aggregate_failures do
        expect(response_data[:data]).to be_an(Array)
        expect(response_data[:data].length).to eq(3)

        post_ids = response_data[:data].map { |post| post[:id] }
        expect(post_ids).to contain_exactly(post1.id.to_s, post2.id.to_s, post3.id.to_s)

        response_data[:data].each do |post_data|
          expect(post_data[:type]).to eq('posts')
          expect(post_data[:attributes]).to have_key('title')
          expect(post_data[:attributes]).to have_key('content')
        end
      end

      it 'includes all users in the included section without duplication', :aggregate_failures do
        user_data = response_data[:included].select { |item| item[:type] == 'users' }
        expect(user_data.length).to eq(2)

        user_ids = user_data.map { |user| user[:id] }
        expect(user_ids).to contain_exactly(user1.id.to_s, user2.id.to_s)

        alice_data = user_data.find { |u| u[:attributes]['name'] == 'Alice Smith' }
        bob_data = user_data.find { |u| u[:attributes]['name'] == 'Bob Johnson' }

        expect(alice_data).not_to be_nil
        expect(bob_data).not_to be_nil
        expect(alice_data[:attributes]['email']).to eq('alice@example.com')
        expect(bob_data[:attributes]['email']).to eq('bob@example.com')
      end

      it 'includes all comments in the included section', :aggregate_failures do
        comment_data = response_data[:included].select { |item| item[:type] == 'comments' }
        expect(comment_data.length).to eq(4)

        comment_contents = comment_data.map { |c| c[:attributes]['content'] }
        expect(comment_contents).to contain_exactly(
          'Great post!',
          'I agree!',
          'Interesting perspective',
          'Thanks for sharing'
        )

        comment_data.each do |comment|
          expect(comment[:type]).to eq('comments')
          expect(comment[:attributes]).to have_key('content')
          expect(comment).to have_key(:meta)
          expect(comment[:meta]).to have_key('created_at')
          expect(comment[:meta]).to have_key('updated_at')
        end
      end

      it 'includes the correct total number of included items', :aggregate_failures do
        # Should include: 2 users + 4 comments = 6 total items
        expect(response_data[:included].length).to eq(6)

        types = response_data[:included].map { |item| item[:type] }
        expect(types.count('users')).to eq(2)
        expect(types.count('comments')).to eq(4)
      end

      it 'maintains unique items in included section (no duplicates)', :aggregate_failures do
        # Verify no duplicate users
        user_items = response_data[:included].select { |item| item[:type] == 'users' }
        user_keys = user_items.map { |item| [item[:type], item[:id]] }
        expect(user_keys.uniq.length).to eq(user_keys.length)

        # Verify no duplicate comments
        comment_items = response_data[:included].select { |item| item[:type] == 'comments' }
        comment_keys = comment_items.map { |item| [item[:type], item[:id]] }
        expect(comment_keys.uniq.length).to eq(comment_keys.length)
      end
    end

    context 'when requesting specific post with nested user comments' do
      before do
        controller.params = { id: post1.id.to_s, include: 'user,user.comments' }
        controller.show
      end

      let(:response_data) { controller.last_render[:json] }

      it 'returns the specific post with all related data', :aggregate_failures do
        expect(response_data[:data][:id]).to eq(post1.id.to_s)
        expect(response_data[:data][:type]).to eq('posts')
        expect(response_data[:data][:attributes]['title']).to eq('First Post')

        # Should include: 1 user (Alice) + all her comments (2 total: one on post1, one on post2)
        expect(response_data[:included].length).to eq(3)

        user_data = response_data[:included].find { |item| item[:type] == 'users' }
        expect(user_data[:attributes]['name']).to eq('Alice Smith')

        comment_data = response_data[:included].select { |item| item[:type] == 'comments' }
        expect(comment_data.length).to eq(2)
        comment_contents = comment_data.map { |c| c[:attributes]['content'] }
        expect(comment_contents).to contain_exactly('I agree!', 'Interesting perspective')
      end
    end
  end

  describe 'Example JSON:API response format' do
    it 'demonstrates the expected response structure for GET /posts?include=user,user.comments' do
      controller_class = Class.new(BaseController) do
        include JPie::Controller
        def self.name = 'PostsController'
        attr_accessor :params, :request, :response

        def initialize
          @params = {}
          @request = MockRequest.new
          @response = MockResponse.new
        end

        def render(options = {}) = @last_render = options
        def action_name = 'show'
        attr_reader :last_render
      end

      controller = controller_class.new
      controller.params = { id: post1.id.to_s, include: 'user,user.comments' }
      controller.show

      response = controller.last_render[:json]

      # This demonstrates what the actual JSON:API response looks like
      puts "\n--- Example JSON:API Response for GET /posts/#{post1.id}?include=user,user.comments ---"
      puts JSON.pretty_generate(response)
      puts "--- End of example response ---\n"

      # Verify it follows JSON:API spec
      expect(response).to have_key(:data)
      expect(response).to have_key(:included)
      expect(response[:data][:type]).to eq('posts')
      expect(response[:included]).to be_an(Array)
    end
  end
end
