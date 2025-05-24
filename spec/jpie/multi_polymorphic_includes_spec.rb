# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Multiple Polymorphic Includes in Single Request' do
  # Test data setup similar to the comprehensive spec but focused on the specific use case
  let!(:user1) { User.create!(name: 'Alice', email: 'alice@example.com') }
  let!(:user2) { User.create!(name: 'Bob', email: 'bob@example.com') }

  let!(:tag_ruby) { Tag.create!(name: 'ruby') }
  let!(:tag_rails) { Tag.create!(name: 'rails') }
  let!(:tag_testing) { Tag.create!(name: 'testing') }
  let!(:tag_api) { Tag.create!(name: 'api') }

  let!(:post1) { Post.create!(title: 'Ruby Tutorial', content: 'Learning Ruby', user: user1) }
  let!(:post2) { Post.create!(title: 'Rails Guide', content: 'Building APIs', user: user2) }

  let!(:comment1) { Comment.create!(content: 'Great tutorial!', user: user2, post: post1) }
  let!(:comment2) { Comment.create!(content: 'Very helpful', user: user1, post: post2) }
  let!(:reply1) { Comment.create!(content: 'Thanks!', user: user1, post: post1, parent_comment: comment1) }

  # Set up polymorphic tags
  let!(:post1_ruby_tag) { Tagging.create!(tag: tag_ruby, taggable: post1) }
  let!(:post1_testing_tag) { Tagging.create!(tag: tag_testing, taggable: post1) }
  let!(:post2_rails_tag) { Tagging.create!(tag: tag_rails, taggable: post2) }
  let!(:post2_api_tag) { Tagging.create!(tag: tag_api, taggable: post2) }

  let!(:comment1_ruby_tag) { Tagging.create!(tag: tag_ruby, taggable: comment1) }
  let!(:comment2_testing_tag) { Tagging.create!(tag: tag_testing, taggable: comment2) }
  let!(:reply1_api_tag) { Tagging.create!(tag: tag_api, taggable: reply1) }

  describe 'Multiple polymorphic includes in a single request' do
    let(:serializer) { JPie::Serializer.new(PostResource) }

    context 'when requesting tags,comments,comments.tags' do
      let(:includes) { ['tags', 'comments', 'comments.tags'] }

      it 'includes all requested resources without duplicates' do
        result = serializer.serialize(post1, {}, includes: includes)

        expect(result[:included]).to be_present

        # Should include post tags
        post_tag_items = result[:included].select { |item| item[:type] == 'tags' }
        expect(post_tag_items.count).to eq(3) # ruby (shared), testing (post), api (reply)

        # Should include comments
        comment_items = result[:included].select { |item| item[:type] == 'comments' }
        expect(comment_items.count).to eq(2) # comment1 and reply1

        # Verify tag names include both post tags and comment tags
        tag_names = post_tag_items.map { |tag| tag[:attributes]['name'] }
        expect(tag_names).to contain_exactly('ruby', 'testing', 'api')
      end

      it 'properly deduplicates tags that appear on both posts and comments' do
        result = serializer.serialize(post1, {}, includes: includes)

        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        tag_ids = tag_items.map { |tag| tag[:id] }

        # Should not have duplicate tag IDs
        expect(tag_ids.uniq.length).to eq(tag_ids.length)

        # Specifically check that ruby tag (which is on both post and comment) appears only once
        ruby_tags = tag_items.select { |tag| tag[:attributes]['name'] == 'ruby' }
        expect(ruby_tags.count).to eq(1)
      end
    end

    context 'when requesting multiple includes with overlap' do
      let(:includes) { ['tags', 'comments.tags', 'comments.user'] }

      it 'handles overlapping include paths efficiently' do
        result = serializer.serialize(post1, {}, includes: includes)

        expect(result[:included]).to be_present

        # Check that we have the expected resource types
        included_types = result[:included].map { |item| item[:type] }.uniq.sort
        expect(included_types).to contain_exactly('comments', 'tags', 'users')

        # Verify we have proper counts without duplication
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }
        user_items = result[:included].select { |item| item[:type] == 'users' }

        expect(tag_items.count).to eq(3) # ruby, testing, api
        expect(comment_items.count).to eq(2) # comment1, reply1
        expect(user_items.count).to eq(2) # user1, user2
      end
    end

    context 'when serializing multiple posts with polymorphic includes' do
      let(:includes) { ['tags', 'comments', 'comments.tags'] }

      it 'includes resources from all posts without duplication' do
        result = serializer.serialize([post1, post2], {}, includes: includes)

        expect(result[:included]).to be_present

        # Should include tags from both posts and their comments
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        tag_names = tag_items.map { |tag| tag[:attributes]['name'] }.sort
        expect(tag_names).to contain_exactly('api', 'rails', 'ruby', 'testing')

        # Should include comments from both posts
        comment_items = result[:included].select { |item| item[:type] == 'comments' }
        expect(comment_items.count).to eq(3) # comment1, comment2, reply1

        # Verify no duplicate resources
        tag_ids = tag_items.map { |tag| tag[:id] }
        comment_ids = comment_items.map { |comment| comment[:id] }

        expect(tag_ids.uniq.length).to eq(tag_ids.length)
        expect(comment_ids.uniq.length).to eq(comment_ids.length)
      end
    end

    context 'with very complex polymorphic include paths' do
      let(:includes) { ['tags.posts.user', 'comments.tags.posts', 'user'] }

      it 'handles deeply nested polymorphic includes across multiple paths' do
        result = serializer.serialize(post1, {}, includes: includes)

        expect(result[:included]).to be_present

        # Should contain all the expected types
        included_types = result[:included].map { |item| item[:type] }.uniq.sort
        expect(included_types).to include('comments', 'posts', 'tags', 'users')

        # Verify deduplication works across complex paths
        user_items = result[:included].select { |item| item[:type] == 'users' }
        post_items = result[:included].select { |item| item[:type] == 'posts' }

        # Should not have duplicate users or posts
        user_ids = user_items.map { |u| u[:id] }
        post_ids = post_items.map { |p| p[:id] }

        expect(user_ids.uniq.length).to eq(user_ids.length)
        expect(post_ids.uniq.length).to eq(post_ids.length)
      end
    end
  end

  describe 'Controller integration with multiple polymorphic includes' do
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

        # Make protected method public for testing
        public :render_jsonapi

        private

        def model_class
          Post
        end
      end
    end

    let(:controller) { controller_class.new }

    before do
      # Mock ApplicationController for tests
      stub_const('ApplicationController', Class.new do
        def self.rescue_from(exception_class, with: nil)
          # Mock implementation for testing
        end

        def head(status)
          # Mock implementation
        end
      end)

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

      stub_const('MockResponse', Class.new do
        def headers
          {}
        end
      end)
    end

    it 'parses and processes multiple polymorphic includes correctly' do
      controller.params = { include: 'tags,comments,comments.tags' }

      includes = controller.parse_include_params
      expect(includes).to eq(['tags', 'comments', 'comments.tags'])

      # Test that the includes are properly processed in rendering
      controller.render_jsonapi(post1)

      expect(controller.last_render).to have_key(:json)
      result = controller.last_render[:json]

      expect(result[:included]).to be_present

      # Verify the right types are included
      included_types = result[:included].map { |item| item[:type] }.uniq.sort
      expect(included_types).to contain_exactly('comments', 'tags')
    end
  end
end
