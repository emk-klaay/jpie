# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/updated_resources'

RSpec.describe 'API Comparison: With vs Without Join Table Exposure' do
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

  describe 'Old API - Exposes join tables' do
    context 'when using the original resource classes' do
      let(:serializer) { JPie::Serializer.new(PostResource) }

      it 'allows access to taggings but exposes internal structure' do
        # This works but exposes the join table implementation
        result = serializer.serialize(post, {}, includes: ['taggings', 'taggings.tag'])

        expect(result[:included]).to be_present

        # Exposes internal taggings structure
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        tag_items = result[:included].select { |item| item[:type] == 'tags' }

        expect(tagging_items.count).to eq(1)
        expect(tag_items.count).to eq(1)

        # Clients need to understand the join table structure
        puts "Old API exposes internal taggings: #{tagging_items.count} tagging records"
      end

      it 'can include tags directly (already supported)' do
        result = serializer.serialize(post, {}, includes: ['tags'])

        expect(result[:included]).to be_present
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        expect(tag_items.count).to eq(1)
        expect(tag_items.first[:attributes]['name']).to eq('ruby')

        # But the resource still exposes taggings as a relationship
        expect(PostResource._relationships.keys).to include(:taggings)
      end
    end
  end

  describe 'New API - Hides join tables' do
    context 'when using updated resource classes' do
      let(:serializer) { JPie::Serializer.new(UpdatedPostResource) }

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
        expect(UpdatedPostResource._relationships.keys).not_to include(:taggings)
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

    context 'Tag resource with clean polymorphic back-references' do
      let(:serializer) { JPie::Serializer.new(UpdatedTagResource) }

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
      # Old way: GET /posts?include=taggings,taggings.tag
      # New way: GET /posts?include=tags

      old_serializer = JPie::Serializer.new(PostResource)
      new_serializer = JPie::Serializer.new(UpdatedPostResource)

      old_result = old_serializer.serialize(post, {}, includes: ['taggings', 'taggings.tag'])
      new_result = new_serializer.serialize(post, {}, includes: ['tags'])

      # Both get the same tag data
      old_tags = old_result[:included].select { |item| item[:type] == 'tags' }
      new_tags = new_result[:included].select { |item| item[:type] == 'tags' }

      expect(old_tags.first[:attributes]['name']).to eq(new_tags.first[:attributes]['name'])

      # But new API is simpler (no taggings exposed)
      old_taggings = old_result[:included].select { |item| item[:type] == 'taggings' }
      new_taggings = new_result[:included].select { |item| item[:type] == 'taggings' }

      expect(old_taggings.count).to eq(1) # Exposes implementation detail
      expect(new_taggings.count).to eq(0) # Clean API

      puts "Old API includes #{old_result[:included].count} items (including join table)"
      puts "New API includes #{new_result[:included].count} items (business objects only)"
    end
  end
end
