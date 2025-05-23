# frozen_string_literal: true

require 'spec_helper'
require_relative '../support/clean_resources'

RSpec.describe 'Clean Polymorphic API without Exposing Join Tables' do
  # Test data setup
  let!(:alice) { User.create!(name: 'Alice', email: 'alice@example.com') }
  let!(:bob) { User.create!(name: 'Bob', email: 'bob@example.com') }

  let!(:tag_ruby) { Tag.create!(name: 'ruby') }
  let!(:tag_rails) { Tag.create!(name: 'rails') }
  let!(:tag_testing) { Tag.create!(name: 'testing') }

  let!(:ruby_post) { Post.create!(title: 'Ruby Tutorial', content: 'Learning Ruby', user: alice) }
  let!(:rails_post) { Post.create!(title: 'Rails Guide', content: 'Building with Rails', user: bob) }

  let!(:comment1) { Comment.create!(content: 'Great tutorial!', user: bob, post: ruby_post) }
  let!(:comment2) { Comment.create!(content: 'Very helpful', user: alice, post: rails_post) }

  # Set up polymorphic tags (this happens behind the scenes)
  before do
    Tagging.create!(tag: tag_ruby, taggable: ruby_post)
    Tagging.create!(tag: tag_testing, taggable: ruby_post)
    Tagging.create!(tag: tag_rails, taggable: rails_post)

    Tagging.create!(tag: tag_ruby, taggable: comment1)
    Tagging.create!(tag: tag_testing, taggable: comment2)
  end

  describe 'Clean API for polymorphic includes' do
    context 'Post serialization' do
      let(:serializer) { JPie::Serializer.new(CleanPostResource) }

      it 'includes tags directly without exposing join table' do
        result = serializer.serialize(ruby_post, {}, includes: ['tags'])

        expect(result[:included]).to be_present
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        expect(tag_items.count).to eq(2)

        tag_names = tag_items.map { |tag| tag[:attributes]['name'] }
        expect(tag_names).to contain_exactly('ruby', 'testing')
      end

      it 'includes comments and their tags without exposing join table' do
        result = serializer.serialize(ruby_post, {}, includes: ['comments', 'comments.tags'])

        expect(result[:included]).to be_present

        comment_items = result[:included].select { |item| item[:type] == 'comments' }
        tag_items = result[:included].select { |item| item[:type] == 'tags' }

        expect(comment_items.count).to eq(1)

        # Only includes tags from comments, not from the post directly
        expect(tag_items.count).to eq(1) # Only ruby (from comment1)
        tag_names = tag_items.map { |tag| tag[:attributes]['name'] }
        expect(tag_names).to contain_exactly('ruby')

        # Should not expose any tagging resources
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end
    end

    context 'Tag serialization with polymorphic back-references' do
      let(:serializer) { JPie::Serializer.new(CleanTagResource) }

      it 'includes all posts and comments that have this tag' do
        result = serializer.serialize(tag_ruby, {}, includes: %w[tagged_posts tagged_comments])

        expect(result[:included]).to be_present

        post_items = result[:included].select { |item| item[:type] == 'posts' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }

        expect(post_items.count).to eq(1) # ruby_post
        expect(comment_items.count).to eq(1) # comment1

        # Should not expose any tagging resources
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end

      it 'supports deep includes through polymorphic relationships' do
        result = serializer.serialize(tag_ruby, {}, includes: ['tagged_posts.user', 'tagged_comments.user'])

        expect(result[:included]).to be_present

        post_items = result[:included].select { |item| item[:type] == 'posts' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }
        user_items = result[:included].select { |item| item[:type] == 'users' }

        expect(post_items.count).to eq(1)
        expect(comment_items.count).to eq(1)
        expect(user_items.count).to eq(2) # alice and bob

        # Should not expose any tagging resources
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end
    end

    context 'Complex scenarios without join table exposure' do
      it 'handles multiple polymorphic includes across different resource types' do
        post_serializer = JPie::Serializer.new(CleanPostResource)
        result = post_serializer.serialize([ruby_post, rails_post], {}, includes: ['tags', 'comments.tags', 'user'])

        expect(result[:included]).to be_present

        # Verify all expected types are included
        included_types = result[:included].map { |item| item[:type] }.uniq.sort
        expect(included_types).to contain_exactly('comments', 'tags', 'users')

        # Verify we have all the tags from both posts and their comments
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        tag_names = tag_items.map { |tag| tag[:attributes]['name'] }.sort
        expect(tag_names).to contain_exactly('rails', 'ruby', 'testing')

        # Should not expose any tagging resources
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end
    end
  end
end
