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
  let!(:first_comment) { Comment.create!(content: 'First comment', user: user, post: first_post) }
  let!(:second_comment) { Comment.create!(content: 'Second comment', user: user, post: first_post) }
  let!(:third_comment) { Comment.create!(content: 'Third comment', user: user, post: second_post) }

  describe '#serialize with include parameter' do
    let(:serializer) { described_class.new(PostResource) }

    it 'serializes without includes when no includes specified', :aggregate_failures do
      result = serializer.serialize(first_post)

      expect(result).to have_key(:data)
      expect(result).not_to have_key(:included)
      expect(result[:data][:id]).to eq(first_post.id.to_s)
      expect(result[:data][:type]).to eq('posts')
    end

    describe 'when user include is specified' do
      let(:result) { serializer.serialize(first_post, {}, includes: ['user']) }

      it 'includes the data and included sections', :aggregate_failures do
        expect(result).to have_key(:data)
        expect(result).to have_key(:included)
        expect(result[:included]).to be_an(Array)
        expect(result[:included].length).to eq(1)
      end

      it 'includes correct user data in included section', :aggregate_failures do
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
      end

      it 'includes included section for multiple posts' do
        expect(result).to have_key(:included)
      end

      it 'returns array data for multiple posts', :aggregate_failures do
        expect(result[:data]).to be_an(Array)
        expect(result[:data].length).to eq(2)
      end

      it 'deduplicates the same user in included section' do
        # Should only include the user once even though both posts reference the same user
        expect(result[:included].length).to eq(1)
      end

      it 'includes correct user data in deduplicated included section', :aggregate_failures do
        included_user = result[:included].first
        expect(included_user[:id]).to eq(user.id.to_s)
        expect(included_user[:type]).to eq('users')
      end
    end

    it 'handles non-existent relationships gracefully', :aggregate_failures do
      result = serializer.serialize(first_post, {}, includes: ['nonexistent'])

      expect(result).to have_key(:data)
      expect(result).to have_key(:included)
      expect(result[:included]).to be_empty
    end
  end

  describe '#serialize with nested include parameters' do
    let(:serializer) { described_class.new(PostResource) }

    describe 'when user.comments include is specified' do
      let(:result) { serializer.serialize(first_post, {}, includes: ['user.comments']) }

      it 'includes the data, user, and user comments in included section', :aggregate_failures do
        expect(result).to have_key(:data)
        expect(result).to have_key(:included)
        expect(result[:included]).to be_an(Array)
        # Should include 1 user + all comments by that user (3 comments)
        expect(result[:included].length).to eq(4)
      end

      it 'includes user in included section', :aggregate_failures do
        user_data = result[:included].find { |item| item[:type] == 'users' }
        expect(user_data).not_to be_nil
        expect(user_data[:id]).to eq(user.id.to_s)
        expect(user_data[:attributes]['name']).to eq('John Doe')
      end

      it 'includes all user comments in included section', :aggregate_failures do
        comment_data = result[:included].select { |item| item[:type] == 'comments' }
        expect(comment_data.length).to eq(3)

        comment_contents = comment_data.map { |c| c[:attributes]['content'] }
        expect(comment_contents).to contain_exactly('First comment', 'Second comment', 'Third comment')
      end

      it 'maintains proper relationships in comment data', :aggregate_failures do
        comment_data = result[:included].select { |item| item[:type] == 'comments' }
        comment_data.each do |comment|
          expect(comment[:attributes]).to have_key('content')
          expect(comment).to have_key(:meta)
          expect(comment[:meta]).to have_key('created_at')
        end
      end
    end

    describe 'when combining regular and nested includes' do
      let(:result) { serializer.serialize(first_post, {}, includes: ['user', 'user.comments']) }

      it 'includes user only once despite multiple include paths', :aggregate_failures do
        user_data = result[:included].select { |item| item[:type] == 'users' }
        expect(user_data.length).to eq(1)
      end

      it 'includes all related data without duplication', :aggregate_failures do
        expect(result[:included].length).to eq(4) # 1 user + 3 comments

        # Verify user is included
        user_data = result[:included].find { |item| item[:type] == 'users' }
        expect(user_data[:id]).to eq(user.id.to_s)

        # Verify comments are included
        comment_data = result[:included].select { |item| item[:type] == 'comments' }
        expect(comment_data.length).to eq(3)
      end
    end

    describe 'when nested relationship does not exist' do
      let(:result) { serializer.serialize(first_post, {}, includes: ['user.nonexistent']) }

      it 'includes the top-level relationship but ignores non-existent nested relationships', :aggregate_failures do
        expect(result).to have_key(:data)
        expect(result).to have_key(:included)

        # Should include the user but not fail on nonexistent relationship
        user_data = result[:included].find { |item| item[:type] == 'users' }
        expect(user_data).not_to be_nil
        expect(user_data[:id]).to eq(user.id.to_s)
      end
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

    it 'parses nested include parameters' do
      controller.params = { include: 'user.comments' }
      includes = controller.send(:parse_include_params)

      expect(includes).to eq(['user.comments'])
    end

    it 'parses multiple nested include parameters' do
      controller.params = { include: 'user.comments,user.posts' }
      includes = controller.send(:parse_include_params)

      expect(includes).to eq(['user.comments', 'user.posts'])
    end

    it 'parses mixed regular and nested include parameters' do
      controller.params = { include: 'user,user.comments,posts' }
      includes = controller.send(:parse_include_params)

      expect(includes).to eq(['user', 'user.comments', 'posts'])
    end

    it 'strips whitespace from nested include parameters' do
      controller.params = { include: ' user.comments , user.posts ' }
      includes = controller.send(:parse_include_params)

      expect(includes).to eq(['user.comments', 'user.posts'])
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
      it 'includes post data and related user data with correct content type', :aggregate_failures do
        user = User.create!(name: 'John Doe', email: 'john@example.com')
        post = Post.create!(title: 'Test Post', content: 'Content', user: user)

        controller.params = { id: post.id.to_s, include: 'user' }
        controller.show
        response_data = controller.last_render[:json]

        expect(response_data).to have_key(:data)
        expect(response_data).to have_key(:included)
      end

      it 'includes correct post data in main section', :aggregate_failures do
        user = User.create!(name: 'John Doe', email: 'john@example.com')
        post = Post.create!(title: 'Test Post', content: 'Content', user: user)

        controller.params = { id: post.id.to_s, include: 'user' }
        controller.show
        response_data = controller.last_render[:json]

        expect(response_data[:data][:id]).to eq(post.id.to_s)
        expect(response_data[:data][:type]).to eq('posts')
      end

      it 'includes correct included section structure', :aggregate_failures do
        user = User.create!(name: 'John Doe', email: 'john@example.com')
        post = Post.create!(title: 'Test Post', content: 'Content', user: user)

        controller.params = { id: post.id.to_s, include: 'user' }
        controller.show
        response_data = controller.last_render[:json]

        expect(response_data[:included]).to be_an(Array)
        expect(response_data[:included].length).to eq(1)
      end

      it 'includes correct user data in included section', :aggregate_failures do
        user = User.create!(name: 'John Doe', email: 'john@example.com')
        post = Post.create!(title: 'Test Post', content: 'Content', user: user)

        controller.params = { id: post.id.to_s, include: 'user' }
        controller.show
        response_data = controller.last_render[:json]

        included_user = response_data[:included].first
        expect(included_user[:id]).to eq(user.id.to_s)
        expect(included_user[:type]).to eq('users')
      end

      it 'includes correct user attributes in included section', :aggregate_failures do
        user = User.create!(name: 'John Doe', email: 'john@example.com')
        post = Post.create!(title: 'Test Post', content: 'Content', user: user)

        controller.params = { id: post.id.to_s, include: 'user' }
        controller.show
        response_data = controller.last_render[:json]

        included_user = response_data[:included].first
        expect(included_user[:attributes]['name']).to eq('John Doe')
        expect(included_user[:attributes]['email']).to eq('john@example.com')
      end

      it 'returns correct content type' do
        user = User.create!(name: 'John Doe', email: 'john@example.com')
        post = Post.create!(title: 'Test Post', content: 'Content', user: user)

        controller.params = { id: post.id.to_s, include: 'user' }
        controller.show

        expect(controller.last_render[:content_type]).to eq('application/vnd.api+json')
      end
    end

    it 'renders post without included data when no include parameter is provided', :aggregate_failures do
      # Set up data
      user = User.create!(name: 'John Doe', email: 'john@example.com')
      post = Post.create!(title: 'Test Post', content: 'Content', user: user)

      # Simulate controller request without include parameter
      controller.params = { id: post.id.to_s }
      controller.show

      response_data = controller.last_render[:json]
      expect(response_data).to have_key(:data)
      expect(response_data).not_to have_key(:included)
    end

    it 'includes correct post data when no include parameter provided', :aggregate_failures do
      user = User.create!(name: 'John Doe', email: 'john@example.com')
      post = Post.create!(title: 'Test Post', content: 'Content', user: user)

      controller.params = { id: post.id.to_s }
      controller.show

      response_data = controller.last_render[:json]
      expect(response_data[:data][:id]).to eq(post.id.to_s)
      expect(response_data[:data][:type]).to eq('posts')
    end

    describe 'when nested include=user.comments parameter is provided' do
      it 'includes post data, user, and user comments with correct structure', :aggregate_failures do
        user = User.create!(name: 'John Doe', email: 'john@example.com')
        post = Post.create!(title: 'Test Post', content: 'Content', user: user)
        Comment.create!(content: 'First comment', user: user, post: post)
        Comment.create!(content: 'Second comment', user: user, post: post)

        controller.params = { id: post.id.to_s, include: 'user.comments' }
        controller.show
        response_data = controller.last_render[:json]

        expect(response_data).to have_key(:data)
        expect(response_data).to have_key(:included)
        expect(response_data[:included]).to be_an(Array)
        expect(response_data[:included].length).to eq(3) # 1 user + 2 comments
      end

      it 'includes user and all user comments in included section', :aggregate_failures do
        user = User.create!(name: 'John Doe', email: 'john@example.com')
        post = Post.create!(title: 'Test Post', content: 'Content', user: user)
        Comment.create!(content: 'First comment', user: user, post: post)
        Comment.create!(content: 'Second comment', user: user, post: post)

        controller.params = { id: post.id.to_s, include: 'user.comments' }
        controller.show
        response_data = controller.last_render[:json]

        # Check user is included
        user_data = response_data[:included].find { |item| item[:type] == 'users' }
        expect(user_data).not_to be_nil
        expect(user_data[:id]).to eq(user.id.to_s)
        expect(user_data[:attributes]['name']).to eq('John Doe')

        # Check comments are included
        comment_data = response_data[:included].select { |item| item[:type] == 'comments' }
        expect(comment_data.length).to eq(2)
        comment_contents = comment_data.map { |c| c[:attributes]['content'] }
        expect(comment_contents).to contain_exactly('First comment', 'Second comment')
      end

      it 'returns correct content type for nested includes' do
        user = User.create!(name: 'John Doe', email: 'john@example.com')
        post = Post.create!(title: 'Test Post', content: 'Content', user: user)
        Comment.create!(content: 'Test comment', user: user, post: post)

        controller.params = { id: post.id.to_s, include: 'user.comments' }
        controller.show

        expect(controller.last_render[:content_type]).to eq('application/vnd.api+json')
      end
    end
  end
end
