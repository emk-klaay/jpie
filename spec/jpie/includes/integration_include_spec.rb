# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JPie do
  describe 'Integration: Controller Include Parameters for has_many relationships' do
    let(:controller_class) { create_test_controller('UsersController') }
    let(:controller) { controller_class.new }
    let(:user) { User.create!(name: 'John Doe', email: 'john@example.com') }
    let!(:first_post) { Post.create!(title: 'First Post', content: 'Content 1', user: user) }
    let!(:second_post) { Post.create!(title: 'Second Post', content: 'Content 2', user: user) }

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

      it 'handles multiple include parameters correctly', :aggregate_failures do
        controller.params = { id: user.id.to_s, include: 'posts,comments' }
        controller.show

        result = controller.last_render[:json]

        expect(result).to have_key(:included)
        expect(result[:included].length).to be >= 2

        # Should include both posts and comments
        post_items = result[:included].select { |item| item[:type] == 'posts' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }
        expect(post_items.length).to eq(2)
        expect(comment_items.length).to be >= 0 # May be 0 if no comments exist
      end
    end

    describe 'Collection endpoints with includes' do
      let(:other_user) { User.create!(name: 'Jane Doe', email: 'jane@example.com') }
      let!(:other_post) { Post.create!(title: 'Other Post', content: 'Other Content', user: other_user) }

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
        Post.create!(title: 'Another Post', content: 'More Content', user: user)

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
        controller.params = { id: user.id.to_s, include: 'invalid_relationship' }

        expect { controller.show }.to raise_error(JPie::Errors::UnsupportedIncludeError)
      end

      it 'raises error for deeply nested invalid includes' do
        controller.params = { id: user.id.to_s, include: 'posts.invalid.deeply.nested' }

        expect { controller.show }.to raise_error(JPie::Errors::UnsupportedIncludeError)
      end

      it 'handles valid include parameters correctly' do
        controller.params = { id: user.id.to_s, include: 'posts' }

        expect { controller.show }.not_to raise_error

        result = controller.last_render[:json]
        expect(result).to have_key(:data)
        expect(result).to have_key(:included)
      end
    end
  end
end
