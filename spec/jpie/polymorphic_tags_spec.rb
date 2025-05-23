# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Polymorphic Tags' do
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

  describe 'Serialization with polymorphic includes' do
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

    it 'includes taggings when requested' do
      result = serializer.serialize(post, {}, includes: ['taggings'])
      
      expect(result[:included]).to be_present
      tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
      expect(tagging_items.count).to eq(2)
    end

    it 'supports nested includes like tags.taggings' do
      result = serializer.serialize(post, {}, includes: ['tags.taggings'])
      
      expect(result[:included]).to be_present
      tag_items = result[:included].select { |item| item[:type] == 'tags' }
      tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
      
      expect(tag_items.count).to eq(2)
      expect(tagging_items.count).to be >= 2  # May include taggings from other posts too
    end
  end

  describe 'Comment serialization with polymorphic tags' do
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

  describe 'Advanced polymorphic includes' do
    let(:serializer) { JPie::Serializer.new(TagResource) }

    before do
      # Set up tags with both posts and comments
      Tagging.create!(tag: tag_ruby, taggable: post)
      Tagging.create!(tag: tag_ruby, taggable: comment)
      Tagging.create!(tag: tag_rails, taggable: post)
    end

    it 'includes taggings from tag perspective' do
      result = serializer.serialize(tag_ruby, {}, includes: ['taggings'])
      
      expect(result[:included]).to be_present
      tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
      expect(tagging_items.count).to eq(2) # One for post, one for comment
    end

    it 'supports taggings.taggable includes showing polymorphic resources' do
      result = serializer.serialize(tag_ruby, {}, includes: ['taggings.taggable'])
      
      expect(result[:included]).to be_present
      
      # Should include taggings and the polymorphic taggable objects
      tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
      post_items = result[:included].select { |item| item[:type] == 'posts' }
      comment_items = result[:included].select { |item| item[:type] == 'comments' }
      
      expect(tagging_items.count).to eq(2)
      expect(post_items.count).to eq(1)
      expect(comment_items.count).to eq(1)
    end

    it 'supports complex nested polymorphic includes' do
      # Create a comment on the post and tag it
      reply = Comment.create!(content: 'Reply', user: user, post: post, parent_comment: comment)
      Tagging.create!(tag: tag_testing, taggable: reply)
      
      result = serializer.serialize(tag_testing, {}, includes: ['taggings.taggable.user'])
      
      expect(result[:included]).to be_present
      
      # Should include taggings, the polymorphic objects, and their users
      types_included = result[:included].map { |item| item[:type] }.uniq.sort
      expect(types_included).to include('taggings', 'users')
    end
  end
end 