# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Includes Integration - Controller Behavior' do
  # Set up test data with proper relationships
  let!(:user1) { User.create!(name: 'Alice Smith', email: 'alice@example.com') }
  let!(:user2) { User.create!(name: 'Bob Johnson', email: 'bob@example.com') }

  let!(:post1) { Post.create!(title: 'First Post', content: 'Content of first post', user: user1) }
  let!(:post2) { Post.create!(title: 'Second Post', content: 'Content of second post', user: user2) }
  let!(:post3) { Post.create!(title: 'Third Post', content: 'Content of third post', user: user1) }

  let!(:reply1) { Post.create!(title: 'Great post!', content: 'Reply content 1', user: user2, parent_post: post1) }
  let!(:reply2) { Post.create!(title: 'I agree!', content: 'Reply content 2', user: user1, parent_post: post1) }
  let!(:reply3) do
    Post.create!(title: 'Interesting perspective', content: 'Reply content 3', user: user1, parent_post: post2)
  end
  let!(:reply4) do
    Post.create!(title: 'Thanks for sharing', content: 'Reply content 4', user: user2, parent_post: post3)
  end

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
        expect(result[:included].length).to eq(4) # user1 has 2 main posts + 2 replies
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
        expect(post_ids).to include(post1.id.to_s, post3.id.to_s, reply2.id.to_s, reply3.id.to_s)
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
        controller.params = { id: user1.id.to_s, include: 'posts' }
        controller.show

        result = controller.last_render[:json]

        expect(result).to have_key(:included)
        expect(result[:included].length).to be >= 2

        # Should include posts
        post_items = result[:included].select { |item| item[:type] == 'posts' }
        expect(post_items.length).to eq(4) # user1 has 2 main posts + 2 replies
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
        expect(post_items.length).to be >= 7 # At least 7 posts total (3 main + 4 replies)
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

    describe 'GET /posts?include=user,replies' do
      context 'when requesting all posts with nested replies' do
        before do
          posts_controller.params = { include: 'user,replies' }
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
          expect(response_data[:data].length).to eq(7) # 3 main posts + 4 replies

          main_post_ids = response_data[:data].map { |post| post[:id] }
          expect(main_post_ids).to include(post1.id.to_s, post2.id.to_s, post3.id.to_s)

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

        it 'includes all replies in the included section', :aggregate_failures do
          reply_data = response_data[:included].select { |item| item[:type] == 'posts' }
          expect(reply_data.length).to eq(4) # Only the replies are included

          reply_titles = reply_data.map { |p| p[:attributes]['title'] }
          expect(reply_titles).to contain_exactly(
            'Great post!',
            'I agree!',
            'Interesting perspective',
            'Thanks for sharing'
          )

          reply_data.each do |reply|
            expect(reply[:type]).to eq('posts')
            expect(reply[:attributes]).to have_key('title')
            expect(reply[:attributes]).to have_key('content')
            expect(reply).to have_key(:meta)
            expect(reply[:meta]).to have_key('created_at')
            expect(reply[:meta]).to have_key('updated_at')
          end
        end

        it 'includes the correct total number of included items', :aggregate_failures do
          # Should include: 2 users + 4 replies = 6 total items
          expect(response_data[:included].length).to eq(6)

          types = response_data[:included].map { |item| item[:type] }
          expect(types.count('users')).to eq(2)
          expect(types.count('posts')).to eq(4)
        end

        it 'maintains unique items in included section (no duplicates)', :aggregate_failures do
          # Verify no duplicate users
          user_items = response_data[:included].select { |item| item[:type] == 'users' }
          user_keys = user_items.map { |item| [item[:type], item[:id]] }
          expect(user_keys.uniq.length).to eq(user_keys.length)

          # Verify no duplicate posts
          post_items = response_data[:included].select { |item| item[:type] == 'posts' }
          post_keys = post_items.map { |item| [item[:type], item[:id]] }
          expect(post_keys.uniq.length).to eq(post_keys.length)
        end
      end

      context 'when requesting specific post with nested replies' do
        before do
          posts_controller.params = { id: post1.id.to_s, include: 'user,replies' }
          posts_controller.show
        end

        let(:response_data) { posts_controller.last_render[:json] }

        it 'returns the specific post with all related data', :aggregate_failures do
          expect(response_data[:data][:id]).to eq(post1.id.to_s)
          expect(response_data[:data][:type]).to eq('posts')
          expect(response_data[:data][:attributes]['title']).to eq('First Post')

          # Should include: 1 user (Alice) + replies to post1 (2 replies)
          expect(response_data[:included].length).to eq(3)

          user_data = response_data[:included].find { |item| item[:type] == 'users' }
          expect(user_data[:attributes]['name']).to eq('Alice Smith')

          reply_data = response_data[:included].select { |item| item[:type] == 'posts' && item[:id] != post1.id.to_s }
          expect(reply_data.length).to eq(2)
          reply_titles = reply_data.map { |p| p[:attributes]['title'] }
          expect(reply_titles).to contain_exactly('Great post!', 'I agree!')
        end
      end
    end
  end
end
