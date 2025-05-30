# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Clean API Design - Hiding Join Tables' do
  # Test data setup
  let!(:user) { User.create!(name: 'Alice', email: 'alice@example.com') }
  let!(:tag_ruby) { Tag.create!(name: 'ruby') }
  let!(:tag_rails) { Tag.create!(name: 'rails') }
  let!(:post) { Post.create!(title: 'Ruby Tutorial', content: 'Learning Ruby', user: user) }
  let!(:reply) { Post.create!(title: 'Great tutorial!', content: 'Reply content', user: user, parent_post: post) }

  before do
    Tagging.create!(tag: tag_ruby, taggable: post)
    Tagging.create!(tag: tag_rails, taggable: reply)
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
        result = serializer.serialize(post, {}, includes: ['tags', 'replies.tags', 'user'])

        expect(result[:included]).to be_present

        # Clean result with only meaningful business resources
        included_types = result[:included].map { |item| item[:type] }.uniq.sort
        expect(included_types).to contain_exactly('posts', 'tags', 'users')

        # No internal join table resources
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty

        # All the expected data is still there
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        expect(tag_items.count).to eq(2) # ruby (post) + rails (reply)
      end
    end

    context 'Tag resource with polymorphic back-references' do
      let(:serializer) { JPie::Serializer.new(TagResource) }

      it 'provides clean access to all tagged resources' do
        result = serializer.serialize(tag_ruby, {}, includes: %w[posts])

        expect(result[:included]).to be_present

        # Direct access to tagged resources
        post_items = result[:included].select { |item| item[:type] == 'posts' }

        expect(post_items.count).to eq(1)

        # No join table exposure
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end

      it 'supports semantic relationship names' do
        result = serializer.serialize(tag_ruby, {}, includes: %w[tagged_posts])

        expect(result[:included]).to be_present

        # Semantic names work the same as direct names
        post_items = result[:included].select { |item| item[:type] == 'posts' }

        expect(post_items.count).to eq(1)

        # No join table exposure
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end

      it 'supports deep includes through polymorphic relationships cleanly' do
        result = serializer.serialize(tag_ruby, {}, includes: ['posts.user'])

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

  describe 'Clean Polymorphic API without Exposing Join Tables' do
    # Additional test data for polymorphic scenarios (using unique names to avoid conflicts)
    let!(:alice_poly) { User.create!(name: 'Alice Poly', email: 'alice.poly@example.com') }
    let!(:bob_poly) { User.create!(name: 'Bob Poly', email: 'bob.poly@example.com') }

    let!(:ruby_post_poly) { Post.create!(title: 'Ruby Tutorial Poly', content: 'Learning Ruby Poly', user: alice_poly) }
    let!(:rails_post_poly) do
      Post.create!(title: 'Rails Guide Poly', content: 'Building with Rails Poly', user: bob_poly)
    end

    let!(:reply1_poly) do
      Post.create!(title: 'Great tutorial poly!', content: 'Reply content 1', user: bob_poly,
                   parent_post: ruby_post_poly)
    end
    let!(:reply2_poly) do
      Post.create!(title: 'Very helpful poly', content: 'Reply content 2', user: alice_poly,
                   parent_post: rails_post_poly)
    end

    # Create separate tags for polymorphic tests to avoid conflicts
    let!(:tag_ruby_poly) { Tag.create!(name: 'ruby_poly') }

    before do
      # Set up additional polymorphic tags for comprehensive testing
      Tagging.create!(tag: tag_ruby_poly, taggable: ruby_post_poly)
      Tagging.create!(tag: tag_ruby_poly, taggable: reply1_poly)
    end

    context 'Post serialization with polymorphic includes' do
      let(:post_serializer) { JPie::Serializer.new(PostResource) }

      it 'includes replies and their tags without exposing join table' do
        result = post_serializer.serialize(ruby_post_poly, {}, includes: ['replies', 'replies.tags'])

        expect(result[:included]).to be_present

        reply_items = result[:included].select { |item| item[:type] == 'posts' && item[:id] != ruby_post_poly.id.to_s }
        tag_items = result[:included].select { |item| item[:type] == 'tags' }

        expect(reply_items.count).to eq(1)
        expect(tag_items.count).to eq(1) # Only ruby_poly (from reply1_poly)

        tag_names = tag_items.map { |tag| tag[:attributes]['name'] }
        expect(tag_names).to contain_exactly('ruby_poly')

        # Should not expose any tagging resources
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end
    end

    context 'Tag serialization with polymorphic back-references' do
      let(:tag_serializer) { JPie::Serializer.new(TagResource) }

      it 'includes all posts and replies that have this tag' do
        result = tag_serializer.serialize(tag_ruby_poly, {}, includes: %w[tagged_posts])

        expect(result[:included]).to be_present

        post_items = result[:included].select { |item| item[:type] == 'posts' }

        expect(post_items.count).to eq(2) # ruby_post_poly and reply1_poly

        # Should not expose any tagging resources
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end

      it 'supports deep includes through polymorphic relationships' do
        result = tag_serializer.serialize(tag_ruby_poly, {}, includes: ['tagged_posts.user'])

        expect(result[:included]).to be_present

        post_items = result[:included].select { |item| item[:type] == 'posts' }
        user_items = result[:included].select { |item| item[:type] == 'users' }

        expect(post_items.count).to eq(2)
        expect(user_items.count).to eq(2) # alice_poly and bob_poly

        # Should not expose any tagging resources
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end
    end

    context 'Complex scenarios without join table exposure' do
      it 'handles multiple polymorphic includes across different resource types' do
        result = JPie::Serializer.new(PostResource).serialize([ruby_post_poly, rails_post_poly], {},
                                                              includes: ['tags', 'replies.tags', 'user'])

        expect(result[:included]).to be_present

        # Verify all expected types are included
        included_types = result[:included].map { |item| item[:type] }.uniq.sort
        expect(included_types).to contain_exactly('posts', 'tags', 'users')

        # Verify we have all the tags from both posts and their replies
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        tag_names = tag_items.map { |tag| tag[:attributes]['name'] }.sort
        expect(tag_names).to include('ruby_poly')

        # Should not expose any tagging resources
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end
    end
  end
end
