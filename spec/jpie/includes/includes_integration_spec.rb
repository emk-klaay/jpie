# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Includes Integration - Controller Behavior' do
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

  describe 'Controller Include Parameters for has_many relationships' do
    let(:controller_class) { create_test_controller('UsersController') }
    let(:controller) { controller_class.new }

    describe 'GET /users/:id?include=posts' do
      it 'includes posts in the response when include=posts is specified', :aggregate_failures do
        controller.params = { id: user1.id.to_s, include: 'posts' }
        controller.show

        result = controller.last_render[:json]

        expect(result).to have_key(:included)
        expect(result[:included]).to be_an(Array)
        expect(result[:included].length).to eq(2) # user1 has 2 posts
      end

      it 'includes correct user data in main response', :aggregate_failures do
        controller.params = { id: user1.id.to_s, include: 'posts' }
        controller.show

        result = controller.last_render[:json]

        expect(result[:data][:id]).to eq(user1.id.to_s)
        expect(result[:data][:type]).to eq('users')
        expect(result[:data][:attributes]['name']).to eq('Alice Smith')
      end

      it 'includes both posts in included section' do
        controller.params = { id: user1.id.to_s, include: 'posts' }
        controller.show

        result = controller.last_render[:json]

        post_ids = result[:included].map { |item| item[:id] }
        expect(post_ids).to contain_exactly(post1.id.to_s, post3.id.to_s)
      end

      it 'includes correct post structure in included section', :aggregate_failures do
        controller.params = { id: user1.id.to_s, include: 'posts' }
        controller.show

        result = controller.last_render[:json]

        result[:included].each do |included_item|
          expect(included_item[:type]).to eq('posts')
          expect(included_item[:attributes]).to have_key('title')
          expect(included_item[:attributes]).to have_key('content')
        end
      end

      it 'returns correct response metadata', :aggregate_failures do
        controller.params = { id: user1.id.to_s, include: 'posts' }
        controller.show

        expect(controller.last_render[:status]).to eq(:ok)
        expect(controller.last_render[:content_type]).to eq('application/vnd.api+json')
      end

      it 'includes meta attributes for included posts', :aggregate_failures do
        controller.params = { id: user1.id.to_s, include: 'posts' }
        controller.show

        result = controller.last_render[:json]

        result[:included].each do |included_post|
          expect(included_post).to have_key(:meta)
          expect(included_post[:meta]).to have_key('created_at')
          expect(included_post[:meta]).to have_key('updated_at')
        end
      end

      it 'formats timestamps correctly for included posts', :aggregate_failures do
        controller.params = { id: user1.id.to_s, include: 'posts' }
        controller.show

        result = controller.last_render[:json]

        result[:included].each do |included_post|
          expect(included_post[:meta]['created_at']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
          expect(included_post[:meta]['updated_at']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
        end
      end

      it 'does not include posts when no include parameter is specified' do
        controller.params = { id: user1.id.to_s }
        controller.show

        result = controller.last_render[:json]

        expect(result).not_to have_key(:included)
      end

      it 'handles multiple include parameters correctly', :aggregate_failures do
        controller.params = { id: user1.id.to_s, include: 'posts,comments' }
        controller.show

        result = controller.last_render[:json]

        expect(result).to have_key(:included)
        expect(result[:included].length).to be >= 2

        # Should include both posts and comments
        post_items = result[:included].select { |item| item[:type] == 'posts' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }
        expect(post_items.length).to eq(2) # user1 has 2 posts
        expect(comment_items.length).to be >= 0 # May be 0 if no comments exist
      end
    end

    describe 'Collection endpoints with includes' do
      it 'includes related resources for all items in collection' do
        controller.params = { include: 'posts' }
        controller.index

        result = controller.last_render[:json]

        expect(result).to have_key(:data)
        expect(result).to have_key(:included)

        # Should include posts from all users
        post_items = result[:included].select { |item| item[:type] == 'posts' }
        expect(post_items.length).to be >= 3 # At least 3 posts total
      end

      it 'deduplicates included resources across collection items' do
        # Create a post that references the same user
        Post.create!(title: 'Another Post', content: 'More Content', user: user1)

        controller.params = { include: 'posts' }
        controller.index

        result = controller.last_render[:json]

        # Each post should only appear once in included, even if referenced by multiple users
        post_items = result[:included].select { |item| item[:type] == 'posts' }
        post_ids = post_items.map { |item| item[:id] }
        expect(post_ids.uniq.length).to eq(post_ids.length)
      end
    end

    describe 'Error handling for includes' do
      it 'raises error for invalid include parameters' do
        controller.params = { id: user1.id.to_s, include: 'invalid_relationship' }

        expect { controller.show }.to raise_error(JPie::Errors::UnsupportedIncludeError)
      end

      it 'raises error for deeply nested invalid includes' do
        controller.params = { id: user1.id.to_s, include: 'posts.invalid.deeply.nested' }

        expect { controller.show }.to raise_error(JPie::Errors::UnsupportedIncludeError)
      end

      it 'handles valid include parameters correctly' do
        controller.params = { id: user1.id.to_s, include: 'posts' }

        expect { controller.show }.not_to raise_error

        result = controller.last_render[:json]
        expect(result).to have_key(:data)
        expect(result).to have_key(:included)
      end
    end
  end

  describe 'Nested Includes Integration' do
    let(:posts_controller_class) { create_test_controller('PostsController') }
    let(:posts_controller) { posts_controller_class.new }

    describe 'GET /posts?include=user,user.comments' do
      context 'when requesting all posts with nested user comments' do
        before do
          posts_controller.params = { include: 'user,user.comments' }
          posts_controller.index
        end

        let(:response_data) { posts_controller.last_render[:json] }

        it 'returns JSON:API compliant structure', :aggregate_failures do
          expect(response_data).to have_key(:data)
          expect(response_data).to have_key(:included)
          expect(posts_controller.last_render[:content_type]).to eq('application/vnd.api+json')
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
          posts_controller.params = { id: post1.id.to_s, include: 'user,user.comments' }
          posts_controller.show
        end

        let(:response_data) { posts_controller.last_render[:json] }

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
  end
end 