# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Comprehensive Polymorphic Includes' do
  # Set up a complex data structure with polymorphic tags
  let!(:user1) { User.create!(name: 'Alice', email: 'alice@example.com') }
  let!(:user2) { User.create!(name: 'Bob', email: 'bob@example.com') }

  let!(:tag_ruby) { Tag.create!(name: 'ruby') }
  let!(:tag_rails) { Tag.create!(name: 'rails') }
  let!(:tag_testing) { Tag.create!(name: 'testing') }
  let!(:tag_api) { Tag.create!(name: 'api') }

  let!(:post1) { Post.create!(title: 'Ruby Tutorial', content: 'Learning Ruby', user: user1) }
  let!(:post2) { Post.create!(title: 'Rails Guide', content: 'Building APIs', user: user2) }

  let!(:comment1) { Comment.create!(content: 'Great tutorial!', user: user2, post: post1) }
  let!(:comment2) { Comment.create!(content: 'Very helpful', user: user1, post: post2) }
  let!(:reply1) { Comment.create!(content: 'Thanks!', user: user1, post: post1, parent_comment: comment1) }

  # Set up polymorphic tags
  let!(:post1_ruby_tag) { Tagging.create!(tag: tag_ruby, taggable: post1) }
  let!(:post1_testing_tag) { Tagging.create!(tag: tag_testing, taggable: post1) }
  let!(:post2_rails_tag) { Tagging.create!(tag: tag_rails, taggable: post2) }
  let!(:post2_api_tag) { Tagging.create!(tag: tag_api, taggable: post2) }

  let!(:comment1_ruby_tag) { Tagging.create!(tag: tag_ruby, taggable: comment1) }
  let!(:comment2_testing_tag) { Tagging.create!(tag: tag_testing, taggable: comment2) }
  let!(:reply1_api_tag) { Tagging.create!(tag: tag_api, taggable: reply1) }

  describe 'Complex polymorphic scenarios' do
    context 'Posts with polymorphic tag includes' do
      let(:serializer) { JPie::Serializer.new(PostResource) }

      it 'includes tags through polymorphic relationship' do
        result = serializer.serialize(post1, {}, includes: ['tags'])

        expect(result[:included]).to be_present
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        expect(tag_items.count).to eq(2)

        tag_names = tag_items.map { |tag| tag[:attributes]['name'] }
        expect(tag_names).to contain_exactly('ruby', 'testing')
      end

      it 'includes taggings and their polymorphic references' do
        result = serializer.serialize(post1, {}, includes: ['taggings.tag'])

        expect(result[:included]).to be_present
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        tag_items = result[:included].select { |item| item[:type] == 'tags' }

        expect(tagging_items.count).to eq(2)
        expect(tag_items.count).to eq(2)
      end

      it 'supports complex nested includes with comments and their tags' do
        result = serializer.serialize(post1, {}, includes: ['comments.tags', 'tags'])

        expect(result[:included]).to be_present

        # Should include post tags + comment tags
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }

        expect(comment_items.count).to eq(2) # comment1 and reply1
        expect(tag_items.count).to eq(3) # ruby (shared), testing (post), api (reply)

        tag_names = tag_items.map { |tag| tag[:attributes]['name'] }
        expect(tag_names).to contain_exactly('ruby', 'testing', 'api')
      end
    end

    context 'Tags with polymorphic includes to multiple types' do
      let(:serializer) { JPie::Serializer.new(TagResource) }

      it 'includes both posts and comments that share the same tag' do
        result = serializer.serialize(tag_ruby, {}, includes: %w[posts comments])

        expect(result[:included]).to be_present
        post_items = result[:included].select { |item| item[:type] == 'posts' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }

        expect(post_items.count).to eq(1) # post1 has ruby tag
        expect(comment_items.count).to eq(1) # comment1 has ruby tag

        expect(post_items.first[:attributes]['title']).to eq('Ruby Tutorial')
        expect(comment_items.first[:attributes]['content']).to eq('Great tutorial!')
      end

      it 'supports very deep polymorphic includes' do
        # Include the tag's taggings, their polymorphic taggables, and the users of those taggables
        result = serializer.serialize(tag_ruby, {}, includes: ['taggings.taggable.user'])

        expect(result[:included]).to be_present

        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        post_items = result[:included].select { |item| item[:type] == 'posts' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }
        user_items = result[:included].select { |item| item[:type] == 'users' }

        expect(tagging_items.count).to eq(2) # One for post1, one for comment1
        expect(post_items.count).to eq(1) # post1
        expect(comment_items.count).to eq(1) # comment1
        expect(user_items.count).to eq(2) # user1 (post author) and user2 (comment author)
      end

      it 'supports parallel polymorphic paths with proper deduplication' do
        # Multiple paths that might include the same resources
        includes = ['posts.user', 'comments.user', 'taggings.taggable.user']
        result = serializer.serialize(tag_ruby, {}, includes: includes)

        expect(result[:included]).to be_present
        user_items = result[:included].select { |item| item[:type] == 'users' }

        # Should deduplicate users even when they come from multiple paths
        user_ids = user_items.map { |u| u[:id] }
        expect(user_ids.uniq.length).to eq(user_ids.length)
        expect(user_items.count).to eq(2) # user1 and user2
      end
    end

    context 'Cross-type polymorphic relationships' do
      it 'handles comments with tags that also tag posts' do
        serializer = JPie::Serializer.new(CommentResource)
        result = serializer.serialize(comment1, {}, includes: ['tags.posts'])

        expect(result[:included]).to be_present
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        post_items = result[:included].select { |item| item[:type] == 'posts' }

        # comment1 has ruby tag, which is also on post1
        expect(tag_items.count).to eq(1) # ruby tag
        expect(post_items.count).to eq(1) # post1 also has ruby tag
      end

      it 'supports extremely complex polymorphic chains' do
        # From a comment, include its tags, then posts that also have those tags, then users of those posts
        serializer = JPie::Serializer.new(CommentResource)
        result = serializer.serialize(comment1, {}, includes: ['tags.posts.user'])

        expect(result[:included]).to be_present

        types_included = result[:included].map { |item| item[:type] }.uniq.sort
        expect(types_included).to include('tags', 'posts', 'users')

        # Verify the chain: comment1 -> ruby tag -> post1 -> user1
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        post_items = result[:included].select { |item| item[:type] == 'posts' }
        user_items = result[:included].select { |item| item[:type] == 'users' }

        expect(tag_items.first[:attributes]['name']).to eq('ruby')
        expect(post_items.first[:attributes]['title']).to eq('Ruby Tutorial')
        expect(user_items.first[:attributes]['name']).to eq('Alice')
      end
    end
  end

  describe 'JSON:API compliance with polymorphic data' do
    it 'produces valid JSON:API structure with polymorphic includes' do
      serializer = JPie::Serializer.new(TagResource)
      result = serializer.serialize(tag_ruby, {}, includes: ['taggings.taggable'])

      # Should have proper JSON:API structure
      expect(result).to have_key(:data)
      expect(result).to have_key(:included)

      # Data should be a single tag
      expect(result[:data][:type]).to eq('tags')
      expect(result[:data][:attributes]['name']).to eq('ruby')

      # Included should contain taggings and polymorphic objects
      included_types = result[:included].map { |item| item[:type] }.uniq.sort
      expect(included_types).to contain_exactly('comments', 'posts', 'taggings')

      # All included items should have proper structure
      result[:included].each do |item|
        expect(item).to have_key(:id)
        expect(item).to have_key(:type)
        expect(item).to have_key(:attributes)
      end
    end
  end
end
