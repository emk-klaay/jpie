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

  describe 'Controller include parameter integration' do
    let(:controller_class) { create_test_controller('PostsController') }
    let(:controller) { controller_class.new }

    describe 'when include=user parameter is provided' do
      it 'includes user in the response', :aggregate_failures do
        controller.params = { id: first_post.id.to_s, include: 'user' }
        controller.show

        result = controller.last_render[:json]

        expect(result).to have_key(:included)
        expect(result[:included]).to be_an(Array)
        expect(result[:included].length).to eq(1)

        included_user = result[:included].first
        expect(included_user[:id]).to eq(user.id.to_s)
        expect(included_user[:type]).to eq('users')
      end

      it 'returns correct response metadata', :aggregate_failures do
        controller.params = { id: first_post.id.to_s, include: 'user' }
        controller.show

        expect(controller.last_render[:status]).to eq(:ok)
        expect(controller.last_render[:content_type]).to eq('application/vnd.api+json')
      end
    end

    describe 'when nested include=user.comments parameter is provided' do
      it 'includes user and their comments in the response', :aggregate_failures do
        controller.params = { id: first_post.id.to_s, include: 'user.comments' }
        controller.show

        result = controller.last_render[:json]

        expect(result).to have_key(:included)
        expect(result[:included]).to be_an(Array)
        # Should include 1 user + all comments by that user (3 comments)
        expect(result[:included].length).to eq(4)

        user_data = result[:included].find { |item| item[:type] == 'users' }
        expect(user_data).not_to be_nil
        expect(user_data[:id]).to eq(user.id.to_s)

        comment_data = result[:included].select { |item| item[:type] == 'comments' }
        expect(comment_data.length).to eq(3)
      end

      it 'handles multiple include parameters correctly', :aggregate_failures do
        controller.params = { id: first_post.id.to_s, include: 'user,comments' }
        controller.show

        result = controller.last_render[:json]

        expect(result).to have_key(:included)
        
        user_data = result[:included].select { |item| item[:type] == 'users' }
        comment_data = result[:included].select { |item| item[:type] == 'comments' }
        
        expect(user_data.length).to eq(1)
        expect(comment_data.length).to be >= 1
      end
    end

    describe 'when no include parameter is specified' do
      it 'does not include related resources' do
        controller.params = { id: first_post.id.to_s }
        controller.show

        result = controller.last_render[:json]

        expect(result).not_to have_key(:included)
      end

      it 'includes main resource data', :aggregate_failures do
        controller.params = { id: first_post.id.to_s }
        controller.show

        result = controller.last_render[:json]

        expect(result[:data][:id]).to eq(first_post.id.to_s)
        expect(result[:data][:type]).to eq('posts')
      end
    end
  end
end
