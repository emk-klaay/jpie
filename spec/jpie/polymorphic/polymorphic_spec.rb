# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'JPie Polymorphic Functionality' do
  # Test models for polymorphic associations
  let!(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let!(:post1) { Post.create!(title: 'Test Post 1', content: 'Test content 1', user: user) }
  let!(:post2) { Post.create!(title: 'Test Post 2', content: 'Test content 2', user: user) }
  let!(:reply_post) { Post.create!(title: 'Reply Post', content: 'Reply content', user: user, parent_post: post1) }

  let!(:tag_ruby) { Tag.create!(name: 'ruby') }
  let!(:tag_rails) { Tag.create!(name: 'rails') }
  let!(:tag_testing) { Tag.create!(name: 'testing') }

  describe 'Polymorphic Tags - Clean API' do
    describe 'Polymorphic associations' do
      it 'allows posts to have tags' do
        # Create taggings for the post
        Tagging.create!(tag: tag_ruby, taggable: post1)
        Tagging.create!(tag: tag_rails, taggable: post1)

        expect(post1.tags.count).to eq(2)
        expect(post1.tags.map(&:name)).to contain_exactly('ruby', 'rails')
      end

      it 'allows different posts to have different tags' do
        # Create taggings for different posts
        Tagging.create!(tag: tag_testing, taggable: post2)
        Tagging.create!(tag: tag_ruby, taggable: post2)

        expect(post2.tags.count).to eq(2)
        expect(post2.tags.map(&:name)).to contain_exactly('testing', 'ruby')
      end

      it 'tags can belong to multiple posts' do
        # Same tag on both posts
        Tagging.create!(tag: tag_ruby, taggable: post1)
        Tagging.create!(tag: tag_ruby, taggable: post2)

        expect(tag_ruby.posts).to include(post1, post2)
        expect(tag_ruby.taggings.count).to eq(2)
      end

      it 'supports polymorphic taggable with self-referencing posts' do
        # Tag both parent and reply posts
        Tagging.create!(tag: tag_ruby, taggable: post1)
        Tagging.create!(tag: tag_ruby, taggable: reply_post)

        expect(tag_ruby.posts).to include(post1, reply_post)
        expect(post1.tags).to include(tag_ruby)
        expect(reply_post.tags).to include(tag_ruby)
      end
    end

    describe 'Serialization with polymorphic includes - Clean API' do
      let(:post_serializer) { JPie::Serializer.new(PostResource) }

      before do
        # Set up test data with tags
        Tagging.create!(tag: tag_ruby, taggable: post1)
        Tagging.create!(tag: tag_rails, taggable: post1)
        Tagging.create!(tag: tag_testing, taggable: reply_post)
      end

      it 'includes tags when requested' do
        result = post_serializer.serialize(post1, {}, includes: ['tags'])

        expect(result[:included]).to be_present
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        expect(tag_items.count).to eq(2)

        tag_names = tag_items.map { |tag| tag[:attributes]['name'] }
        expect(tag_names).to contain_exactly('ruby', 'rails')
      end

      it 'hides join table in clean API' do
        result = post_serializer.serialize(post1, {}, includes: ['tags'])

        # Should not expose taggings in clean API
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty

        # But should have the tags
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        expect(tag_items.count).to eq(2)
      end

      it 'supports complex includes through tags' do
        # Create another post with shared tags
        post3 = Post.create!(title: 'Another Post', content: 'More content', user: user)
        Tagging.create!(tag: tag_ruby, taggable: post3)

        result = post_serializer.serialize(post1, {}, includes: ['tags', 'replies.tags'])

        expect(result[:included]).to be_present
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        reply_items = result[:included].select { |item| item[:type] == 'posts' && item[:id] == reply_post.id.to_s }

        expect(tag_items.count).to eq(3) # ruby, rails from post1 + testing from reply_post
        expect(reply_items.count).to eq(1)

        # Should not expose taggings
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end
    end

    describe 'Reply post serialization with polymorphic tags - Clean API' do
      let(:post_serializer) { JPie::Serializer.new(PostResource) }

      before do
        Tagging.create!(tag: tag_testing, taggable: reply_post)
        Tagging.create!(tag: tag_ruby, taggable: reply_post)
      end

      it 'includes reply post tags when requested' do
        result = post_serializer.serialize(reply_post, {}, includes: ['tags'])

        expect(result[:included]).to be_present
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        expect(tag_items.count).to eq(2)

        tag_names = tag_items.map { |tag| tag[:attributes]['name'] }
        expect(tag_names).to contain_exactly('testing', 'ruby')
      end
    end

    describe 'Tag serialization with back-references - Clean API' do
      let(:tag_serializer) { JPie::Serializer.new(TagResource) }

      before do
        # Set up polymorphic associations
        Tagging.create!(tag: tag_ruby, taggable: post1)
        Tagging.create!(tag: tag_ruby, taggable: post2)
        Tagging.create!(tag: tag_ruby, taggable: reply_post)
      end

      it 'includes tagged posts directly' do
        result = tag_serializer.serialize(tag_ruby, {}, includes: ['posts'])

        expect(result[:included]).to be_present
        post_items = result[:included].select { |item| item[:type] == 'posts' }
        expect(post_items.count).to eq(3)

        post_titles = post_items.map { |post| post[:attributes]['title'] }
        expect(post_titles).to contain_exactly('Test Post 1', 'Test Post 2', 'Reply Post')

        # Should not expose taggings
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end

      it 'supports deep includes through polymorphic relationships cleanly' do
        result = tag_serializer.serialize(tag_ruby, {}, includes: ['posts.user'])

        expect(result[:included]).to be_present

        post_items = result[:included].select { |item| item[:type] == 'posts' }
        user_items = result[:included].select { |item| item[:type] == 'users' }

        expect(post_items.count).to eq(3)
        expect(user_items.count).to eq(1)
        expect(user_items.first[:attributes]['name']).to eq('Test User')

        # Should not expose taggings
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end
    end
  end

  describe 'Polymorphic Serialization with Self-Referencing Models' do
    let(:serializer) { JPie::Serializer.new(PostResource) }

    before do
      # Set up tags on both parent and reply posts
      Tagging.create!(tag: tag_ruby, taggable: post1)
      Tagging.create!(tag: tag_rails, taggable: reply_post)
    end

    it 'correctly serializes posts with different tag associations' do
      posts = [post1, reply_post]
      result = serializer.serialize(posts, {}, includes: ['tags'])

      expect(result[:data].size).to eq(2)

      # Verify all posts are properly serialized
      titles = result[:data].map { |p| p[:attributes]['title'] }
      expect(titles).to include('Test Post 1', 'Reply Post')

      # Verify tags are included
      tag_items = result[:included].select { |item| item[:type] == 'tags' }
      expect(tag_items.count).to eq(2)
      tag_names = tag_items.map { |tag| tag[:attributes]['name'] }
      expect(tag_names).to contain_exactly('ruby', 'rails')
    end

    it 'includes polymorphic relationships when requested' do
      result = serializer.serialize(post1, {}, includes: %w[tags replies])

      expect(result[:included]).to be_present

      tag_items = result[:included].select { |item| item[:type] == 'tags' }
      reply_items = result[:included].select { |item| item[:type] == 'posts' && item[:id] == reply_post.id.to_s }

      expect(tag_items.count).to eq(1) # Only ruby tag on post1
      expect(reply_items.count).to eq(1) # The reply post
    end

    it 'handles complex polymorphic scenarios correctly' do
      result = serializer.serialize([post1, reply_post], {}, includes: ['tags'])

      expect(result[:included]).to be_present

      # Should include tags from both posts
      tag_items = result[:included].select { |item| item[:type] == 'tags' }
      expect(tag_items.count).to eq(2)

      # Verify no taggings are exposed
      tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
      expect(tagging_items).to be_empty
    end
  end

  describe 'Polymorphic Through Association Edge Cases' do
    it 'handles empty polymorphic associations' do
      # Post with no tags
      empty_post = Post.create!(title: 'Empty Post', content: 'No tags', user: user)

      serializer = JPie::Serializer.new(PostResource)
      result = serializer.serialize(empty_post, {}, includes: ['tags'])

      # Should not fail and should not include any tags
      tag_items = result[:included]&.select { |item| item[:type] == 'tags' } || []
      expect(tag_items).to be_empty
    end

    it 'maintains polymorphic integrity across multiple operations' do
      # Create complex associations
      Tagging.create!(tag: tag_ruby, taggable: post1)
      Tagging.create!(tag: tag_rails, taggable: post1)
      Tagging.create!(tag: tag_ruby, taggable: post2)

      # Verify associations work correctly
      expect(post1.tags.count).to eq(2)
      expect(post2.tags.count).to eq(1)
      expect(tag_ruby.posts.count).to eq(2)
      expect(tag_rails.posts.count).to eq(1)
    end

    it 'maintains integrity when removing polymorphic associations' do
      # Create complex associations
      Tagging.create!(tag: tag_ruby, taggable: post1)
      Tagging.create!(tag: tag_rails, taggable: post1)
      Tagging.create!(tag: tag_ruby, taggable: post2)

      # Remove one association
      post1.tags.delete(tag_ruby)

      # Verify integrity is maintained
      expect(post1.tags.count).to eq(1)
      expect(post1.tags).to include(tag_rails)
      expect(post2.tags.count).to eq(1)
      expect(tag_ruby.posts.count).to eq(1)
      expect(tag_ruby.posts).to include(post2)
    end
  end
end
