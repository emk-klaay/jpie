# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Extreme Deep Nesting Test' do
  let!(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let!(:post) { Post.create!(title: 'Test Post', content: 'Content', user: user) }
  let!(:comment) { Comment.create!(content: 'Test comment', user: user, post: post) }
  let!(:like) { Like.create!(user: user, comment: comment) }

  describe 'arbitrarily deep nested includes' do
    let(:serializer) { JPie::Serializer.new(PostResource) }

    it 'supports the requested format: user,user.comments,user.comments.likes,user.comments.comments' do
      # This is the exact format the user requested
      includes = ['user', 'user.comments', 'user.comments.likes', 'user.comments.comments']

      expect do
        result = serializer.serialize(post, {}, includes: includes)
        expect(result[:included]).to be_an(Array)

        # Should include different types of resources
        types = result[:included].map { |item| item[:type] }.uniq
        expect(types).to include('users')
        expect(types).to include('comments') if user.comments.any?
        expect(types).to include('likes') if user.comments.any? && user.comments.any? { |c| c.likes.any? }
      end.not_to raise_error
    end

    it 'supports very deep theoretical nesting' do
      # Test a theoretical very deep chain
      includes = ['user.comments.likes.user.comments.likes.user']

      expect do
        result = serializer.serialize(post, {}, includes: includes)
        expect(result).to have_key(:data)
        expect(result).to have_key(:included)
        expect(result[:included]).to be_an(Array)
      end.not_to raise_error
    end

    it 'handles complex parallel chains as mentioned in the request' do
      # Multiple parallel deep chains
      includes = [
        'user',
        'user.comments',
        'user.comments.likes',
        'user.comments.comments', # This would be replies (comments on comments)
        'comments.user',
        'comments.likes',
        'comments.likes.user'
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
