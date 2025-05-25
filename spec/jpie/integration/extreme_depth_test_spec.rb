# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Extreme Deep Nesting Test' do
  let!(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let!(:post) { Post.create!(title: 'Test Post', content: 'Content', user: user) }
  let!(:reply_post) { Post.create!(title: 'Reply Post', content: 'Reply content', user: user, parent_post: post) }
  let!(:tag) { Tag.create!(name: 'ruby') }

  before do
    # Set up associations for deep nesting tests
    post.tags << tag
    reply_post.tags << tag
  end

  describe 'arbitrarily deep nested includes' do
    let(:serializer) { JPie::Serializer.new(PostResource) }

    it 'supports the requested format: user,user.posts,user.posts.tags,user.posts.replies' do
      # This is adapted from the original format using our simplified models
      includes = ['user', 'user.posts', 'user.posts.tags', 'user.posts.replies']

      expect do
        result = serializer.serialize(post, {}, includes: includes)
        expect(result[:included]).to be_an(Array)

        # Should include different types of resources
        types = result[:included].map { |item| item[:type] }.uniq
        expect(types).to include('users')
        expect(types).to include('posts') if user.posts.any?
        expect(types).to include('tags') if user.posts.any? && user.posts.any? { |p| p.tags.any? }
      end.not_to raise_error
    end

    it 'supports very deep theoretical nesting' do
      # Test a theoretical very deep chain using our available relationships
      includes = ['user.posts.tags.posts.user.posts.tags']

      expect do
        result = serializer.serialize(post, {}, includes: includes)
        expect(result).to have_key(:data)
        expect(result).to have_key(:included)
        expect(result[:included]).to be_an(Array)
      end.not_to raise_error
    end

    it 'handles complex parallel chains as mentioned in the request' do
      # Multiple parallel deep chains using our simplified models
      includes = [
        'user',
        'user.posts',
        'user.posts.tags',
        'user.posts.replies', # Self-referencing posts (replies)
        'replies.user',
        'replies.tags',
        'replies.tags.posts'
      ]

      expect do
        result = serializer.serialize(post, {}, includes: includes)
        expect(result[:included]).to be_an(Array)

        # All resources should be deduplicated properly
        ids_by_type = result[:included].group_by { |item| item[:type] }
        ids_by_type.each do |type, items|
          item_ids = items.map { |item| item[:id] }
          expect(item_ids.uniq.length).to eq(item_ids.length),
                                          "Found duplicate #{type} resources: #{item_ids}"
        end
      end.not_to raise_error
    end
  end
end
