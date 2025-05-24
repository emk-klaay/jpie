# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Polymorphic Tags - Clean API' do
  let!(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let!(:post) { Post.create!(title: 'Test Post', content: 'Content', user: user) }
  let!(:comment) { Comment.create!(content: 'Test comment', user: user, post: post) }

  let!(:tag_ruby) { Tag.create!(name: 'ruby') }
  let!(:tag_rails) { Tag.create!(name: 'rails') }
  let!(:tag_testing) { Tag.create!(name: 'testing') }

  describe 'Polymorphic associations' do
    it 'allows posts to have tags' do
      # Create taggings for the post
      Tagging.create!(tag: tag_ruby, taggable: post)
      Tagging.create!(tag: tag_rails, taggable: post)

      expect(post.tags.count).to eq(2)
      expect(post.tags.map(&:name)).to contain_exactly('ruby', 'rails')
    end

    it 'allows comments to have tags' do
      # Create taggings for the comment
      Tagging.create!(tag: tag_testing, taggable: comment)
      Tagging.create!(tag: tag_ruby, taggable: comment)

      expect(comment.tags.count).to eq(2)
      expect(comment.tags.map(&:name)).to contain_exactly('testing', 'ruby')
    end

    it 'tags can belong to multiple post types' do
      # Same tag on both post and comment
      Tagging.create!(tag: tag_ruby, taggable: post)
      Tagging.create!(tag: tag_ruby, taggable: comment)

      expect(tag_ruby.posts).to include(post)
      expect(tag_ruby.comments).to include(comment)
      expect(tag_ruby.taggings.count).to eq(2)
    end
  end

  describe 'Serialization with polymorphic includes - Clean API' do
    let(:serializer) { JPie::Serializer.new(PostResource) }

    before do
      # Set up test data with tags
      Tagging.create!(tag: tag_ruby, taggable: post)
      Tagging.create!(tag: tag_rails, taggable: post)
      Tagging.create!(tag: tag_testing, taggable: comment)
    end

    it 'includes tags when requested' do
      result = serializer.serialize(post, {}, includes: ['tags'])

      expect(result[:included]).to be_present
      tag_items = result[:included].select { |item| item[:type] == 'tags' }
      expect(tag_items.count).to eq(2)

      tag_names = tag_items.map { |tag| tag[:attributes]['name'] }
      expect(tag_names).to contain_exactly('ruby', 'rails')
    end

    it 'hides join table in clean API' do
      result = serializer.serialize(post, {}, includes: ['tags'])

      # Should not expose taggings in clean API
      tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
      expect(tagging_items).to be_empty

      # But should have the tags
      tag_items = result[:included].select { |item| item[:type] == 'tags' }
      expect(tag_items.count).to eq(2)
    end

    it 'supports complex includes through tags' do
      # Create another post with shared tags
      post2 = Post.create!(title: 'Another Post', content: 'More content', user: user)
      Tagging.create!(tag: tag_ruby, taggable: post2)

      result = serializer.serialize(post, {}, includes: ['tags', 'comments.tags'])

      expect(result[:included]).to be_present
      tag_items = result[:included].select { |item| item[:type] == 'tags' }
      comment_items = result[:included].select { |item| item[:type] == 'comments' }

      expect(tag_items.count).to eq(3) # ruby, rails from post + testing from comment
      expect(comment_items.count).to eq(1)

      # Should not expose taggings
      tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
      expect(tagging_items).to be_empty
    end
  end

  describe 'Comment serialization with polymorphic tags - Clean API' do
    let(:serializer) { JPie::Serializer.new(CommentResource) }

    before do
      Tagging.create!(tag: tag_testing, taggable: comment)
      Tagging.create!(tag: tag_ruby, taggable: comment)
    end

    it 'includes comment tags when requested' do
      result = serializer.serialize(comment, {}, includes: ['tags'])

      expect(result[:included]).to be_present
      tag_items = result[:included].select { |item| item[:type] == 'tags' }
      expect(tag_items.count).to eq(2)

      tag_names = tag_items.map { |tag| tag[:attributes]['name'] }
      expect(tag_names).to contain_exactly('testing', 'ruby')
    end
  end

  describe 'Tag serialization with back-references - Clean API' do
    let(:serializer) { JPie::Serializer.new(TagResource) }

    before do
      # Set up tags with both posts and comments
      Tagging.create!(tag: tag_ruby, taggable: post)
      Tagging.create!(tag: tag_ruby, taggable: comment)
      Tagging.create!(tag: tag_rails, taggable: post)
    end

    it 'includes tagged posts and comments directly' do
      result = serializer.serialize(tag_ruby, {}, includes: %w[posts comments])

      expect(result[:included]).to be_present
      post_items = result[:included].select { |item| item[:type] == 'posts' }
      comment_items = result[:included].select { |item| item[:type] == 'comments' }

      expect(post_items.count).to eq(1)
      expect(comment_items.count).to eq(1)

      # Should not expose taggings
      tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
      expect(tagging_items).to be_empty
    end

    it 'supports semantic relationship names' do
      result = serializer.serialize(tag_ruby, {}, includes: %w[tagged_posts tagged_comments])

      expect(result[:included]).to be_present
      post_items = result[:included].select { |item| item[:type] == 'posts' }
      comment_items = result[:included].select { |item| item[:type] == 'comments' }

      expect(post_items.count).to eq(1)
      expect(comment_items.count).to eq(1)

      # Should not expose taggings
      tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
      expect(tagging_items).to be_empty
    end

    it 'supports deep includes through polymorphic relationships cleanly' do
      # Create a comment on the post and tag it
      reply = Comment.create!(content: 'Reply', user: user, post: post, parent_comment: comment)
      Tagging.create!(tag: tag_testing, taggable: reply)

      result = serializer.serialize(tag_testing, {}, includes: ['tagged_comments.user'])

      expect(result[:included]).to be_present

      # Should include the polymorphic objects and their users, but not taggings
      types_included = result[:included].map { |item| item[:type] }.uniq.sort
      expect(types_included).to contain_exactly('comments', 'users')

      # Should not expose taggings
      tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
      expect(tagging_items).to be_empty
    end
  end
end
