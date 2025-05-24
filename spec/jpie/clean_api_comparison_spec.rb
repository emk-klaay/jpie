# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Clean API Design - Hiding Join Tables' do
  # Test data setup
  let!(:user) { User.create!(name: 'Alice', email: 'alice@example.com') }
  let!(:tag_ruby) { Tag.create!(name: 'ruby') }
  let!(:tag_rails) { Tag.create!(name: 'rails') }
  let!(:post) { Post.create!(title: 'Ruby Tutorial', content: 'Learning Ruby', user: user) }
  let!(:comment) { Comment.create!(content: 'Great tutorial!', user: user, post: post) }

  before do
    Tagging.create!(tag: tag_ruby, taggable: post)
    Tagging.create!(tag: tag_rails, taggable: comment)
  end

  describe 'Clean API - Hides join tables' do
    context 'Post serialization' do
      let(:serializer) { JPie::Serializer.new(PostResource) }

      it 'includes tags directly without exposing join table' do
        result = serializer.serialize(post, {}, includes: ['tags'])

        expect(result[:included]).to be_present
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        expect(tag_items.count).to eq(1)
        expect(tag_items.first[:attributes]['name']).to eq('ruby')

        # Join table is not exposed
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty

        # Clean API: no taggings relationship exposed
        expect(PostResource._relationships.keys).not_to include(:taggings)
      end

      it 'supports complex includes without join table complexity' do
        result = serializer.serialize(post, {}, includes: ['tags', 'comments.tags', 'user'])

        expect(result[:included]).to be_present

        # Clean result with only meaningful business resources
        included_types = result[:included].map { |item| item[:type] }.uniq.sort
        expect(included_types).to contain_exactly('comments', 'tags', 'users')

        # No internal join table resources
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty

        # All the expected data is still there
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        expect(tag_items.count).to eq(2) # ruby (post) + rails (comment)
      end
    end

    context 'Tag resource with polymorphic back-references' do
      let(:serializer) { JPie::Serializer.new(TagResource) }

      it 'provides clean access to all tagged resources' do
        result = serializer.serialize(tag_ruby, {}, includes: %w[posts comments])

        expect(result[:included]).to be_present

        # Direct access to tagged resources
        post_items = result[:included].select { |item| item[:type] == 'posts' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }

        expect(post_items.count).to eq(1)
        expect(comment_items.count).to eq(0) # ruby tag not on any comments in this test

        # No join table exposure
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end

      it 'supports semantic relationship names' do
        result = serializer.serialize(tag_ruby, {}, includes: %w[tagged_posts tagged_comments])

        expect(result[:included]).to be_present

        # Semantic names work the same as direct names
        post_items = result[:included].select { |item| item[:type] == 'posts' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }

        expect(post_items.count).to eq(1)
        expect(comment_items.count).to eq(0) # ruby tag not on any comments in this test

        # No join table exposure
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end

      it 'supports deep includes through polymorphic relationships cleanly' do
        result = serializer.serialize(tag_ruby, {}, includes: ['posts.user', 'comments.user'])

        expect(result[:included]).to be_present

        # Clean business object structure
        included_types = result[:included].map { |item| item[:type] }.uniq.sort
        expect(included_types).to contain_exactly('posts', 'users')

        # No internal implementation details
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end
    end
  end

  describe 'Benefits of the clean API' do
    it 'provides a simpler mental model for API consumers' do
      # Clean way: GET /posts?include=tags
      # Semantic way: GET /tags?include=tagged_posts

      post_serializer = JPie::Serializer.new(PostResource)
      tag_serializer = JPie::Serializer.new(TagResource)

      post_result = post_serializer.serialize(post, {}, includes: ['tags'])
      tag_result = tag_serializer.serialize(tag_ruby, {}, includes: ['tagged_posts'])

      # Both approaches hide implementation details
      post_taggings = post_result[:included].select { |item| item[:type] == 'taggings' }
      tag_taggings = tag_result[:included].select { |item| item[:type] == 'taggings' }

      expect(post_taggings.count).to eq(0) # Clean API
      expect(tag_taggings.count).to eq(0) # Clean API

      # Business objects only
      puts "Post API includes #{post_result[:included].count} items (business objects only)"
      puts "Tag API includes #{tag_result[:included].count} items (business objects only)"
    end

    it 'supports both direct and semantic relationship names' do
      tag_serializer = JPie::Serializer.new(TagResource)
      
      # Both should work identically
      direct_result = tag_serializer.serialize(tag_ruby, {}, includes: ['posts'])
      semantic_result = tag_serializer.serialize(tag_ruby, {}, includes: ['tagged_posts'])

      direct_posts = direct_result[:included].select { |item| item[:type] == 'posts' }
      semantic_posts = semantic_result[:included].select { |item| item[:type] == 'posts' }

      expect(direct_posts.count).to eq(semantic_posts.count)
      expect(direct_posts.first[:id]).to eq(semantic_posts.first[:id])
    end
  end
end
