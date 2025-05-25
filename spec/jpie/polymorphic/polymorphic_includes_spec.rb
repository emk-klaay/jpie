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

  let!(:reply1) { Post.create!(title: 'Great tutorial!', content: 'Reply content 1', user: user2, parent_post: post1) }
  let!(:reply2) { Post.create!(title: 'Very helpful', content: 'Reply content 2', user: user1, parent_post: post2) }
  let!(:reply3) { Post.create!(title: 'Thanks!', content: 'Reply content 3', user: user1, parent_post: post1) }

  # Set up polymorphic tags
  let!(:post1_ruby_tag) { Tagging.create!(tag: tag_ruby, taggable: post1) }
  let!(:post1_testing_tag) { Tagging.create!(tag: tag_testing, taggable: post1) }
  let!(:post2_rails_tag) { Tagging.create!(tag: tag_rails, taggable: post2) }
  let!(:post2_api_tag) { Tagging.create!(tag: tag_api, taggable: post2) }

  let!(:reply1_ruby_tag) { Tagging.create!(tag: tag_ruby, taggable: reply1) }
  let!(:reply2_testing_tag) { Tagging.create!(tag: tag_testing, taggable: reply2) }
  let!(:reply3_api_tag) { Tagging.create!(tag: tag_api, taggable: reply3) }

  describe 'Complex polymorphic scenarios - Clean API' do
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

      it 'hides join tables in clean API' do
        result = serializer.serialize(post1, {}, includes: ['tags'])

        expect(result[:included]).to be_present
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        expect(tag_items.count).to eq(2)

        # Should not expose taggings in clean API
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end

      it 'supports complex nested includes with replies and their tags' do
        result = serializer.serialize(post1, {}, includes: ['replies.tags', 'tags'])

        expect(result[:included]).to be_present

        # Should include post tags + reply tags
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        reply_items = result[:included].select { |item| item[:type] == 'posts' && item[:id] != post1.id.to_s }

        expect(reply_items.count).to eq(2) # reply1 and reply3
        expect(tag_items.count).to eq(3) # ruby (shared), testing (post), api (reply3)

        tag_names = tag_items.map { |tag| tag[:attributes]['name'] }
        expect(tag_names).to contain_exactly('ruby', 'testing', 'api')

        # Should not expose taggings
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end
    end

    context 'Tags with polymorphic includes to multiple types' do
      let(:serializer) { JPie::Serializer.new(TagResource) }

      it 'includes both posts and replies that share the same tag' do
        result = serializer.serialize(tag_ruby, {}, includes: ['posts'])

        expect(result[:included]).to be_present
        post_items = result[:included].select { |item| item[:type] == 'posts' }

        expect(post_items.count).to eq(2) # post1 and reply1 both have ruby tag

        post_titles = post_items.map { |p| p[:attributes]['title'] }
        expect(post_titles).to contain_exactly('Ruby Tutorial', 'Great tutorial!')
      end

      it 'supports deep polymorphic includes through clean relationships' do
        # Include the tag's posts and their users
        result = serializer.serialize(tag_ruby, {}, includes: ['posts.user'])

        expect(result[:included]).to be_present

        post_items = result[:included].select { |item| item[:type] == 'posts' }
        user_items = result[:included].select { |item| item[:type] == 'users' }

        expect(post_items.count).to eq(2) # post1 and reply1
        expect(user_items.count).to eq(2) # user1 (post author) and user2 (reply author)

        # Should not expose taggings
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end

      it 'supports parallel polymorphic paths with proper deduplication' do
        # Multiple paths that might include the same resources
        includes = ['posts.user']
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
      it 'handles replies with tags that also tag posts' do
        serializer = JPie::Serializer.new(PostResource)
        result = serializer.serialize(reply1, {}, includes: ['tags.posts'])

        expect(result[:included]).to be_present
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        post_items = result[:included].select { |item| item[:type] == 'posts' && item[:id] != reply1.id.to_s }

        # reply1 has ruby tag, which is also on post1
        expect(tag_items.count).to eq(1) # ruby tag
        expect(post_items.count).to eq(1) # post1 also has ruby tag
      end

      it 'supports extremely complex polymorphic chains' do
        # From a reply, include its tags, then posts that also have those tags, then users of those posts
        serializer = JPie::Serializer.new(PostResource)
        result = serializer.serialize(reply1, {}, includes: ['tags.posts.user'])

        expect(result[:included]).to be_present

        types_included = result[:included].map { |item| item[:type] }.uniq.sort
        expect(types_included).to include('tags', 'posts', 'users')

        # Verify the chain: reply1 -> ruby tag -> post1 -> user1
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        post_items = result[:included].select { |item| item[:type] == 'posts' && item[:id] != reply1.id.to_s }
        user_items = result[:included].select { |item| item[:type] == 'users' }

        expect(tag_items.first[:attributes]['name']).to eq('ruby')
        expect(post_items.first[:attributes]['title']).to eq('Ruby Tutorial')
        expect(user_items.first[:attributes]['name']).to eq('Alice')

        # Should not expose taggings
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end
    end
  end

  describe 'Multiple polymorphic includes in a single request' do
    let(:serializer) { JPie::Serializer.new(PostResource) }

    context 'when requesting tags,replies,replies.tags' do
      let(:includes) { ['tags', 'replies', 'replies.tags'] }

      it 'includes all requested resources without duplicates' do
        result = serializer.serialize(post1, {}, includes: includes)

        expect(result[:included]).to be_present

        # Should include post tags
        post_tag_items = result[:included].select { |item| item[:type] == 'tags' }
        expect(post_tag_items.count).to eq(3) # ruby (shared), testing (post), api (reply3)

        # Should include replies
        reply_items = result[:included].select { |item| item[:type] == 'posts' && item[:id] != post1.id.to_s }
        expect(reply_items.count).to eq(2) # reply1 and reply3

        # Should not expose taggings
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end

      it 'properly deduplicates tags that appear in multiple contexts' do
        result = serializer.serialize(post1, {}, includes: includes)

        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        tag_ids = tag_items.map { |tag| tag[:id] }

        # Should not have duplicate tags even though ruby appears on both post1 and reply1
        expect(tag_ids.uniq.length).to eq(tag_ids.length)
        expect(tag_items.count).to eq(3) # ruby, testing, api
      end

      it 'maintains correct relationships in complex scenarios' do
        result = serializer.serialize(post1, {}, includes: includes)

        # Verify main post data
        expect(result[:data][:type]).to eq('posts')
        expect(result[:data][:attributes]['title']).to eq('Ruby Tutorial')

        # Verify included data structure
        expect(result[:included]).to be_an(Array)
        types = result[:included].map { |item| item[:type] }.uniq.sort
        expect(types).to contain_exactly('posts', 'tags')
      end
    end
  end

  describe 'Edge cases in polymorphic includes' do
    let(:serializer) { JPie::Serializer.new(PostResource) }

    it 'handles posts with no tags gracefully' do
      empty_post = Post.create!(title: 'Empty Post', content: 'No tags', user: user1)
      result = serializer.serialize(empty_post, {}, includes: ['tags'])

      # Should not fail and should not include any tags
      tag_items = result[:included]&.select { |item| item[:type] == 'tags' } || []
      expect(tag_items).to be_empty
    end

    it 'handles tags with no posts gracefully' do
      empty_tag = Tag.create!(name: 'unused')
      tag_serializer = JPie::Serializer.new(TagResource)
      result = tag_serializer.serialize(empty_tag, {}, includes: ['posts'])

      # Should not fail and should not include any posts
      post_items = result[:included]&.select { |item| item[:type] == 'posts' } || []
      expect(post_items).to be_empty
    end

    it 'maintains polymorphic integrity across complex operations' do
      # Create complex associations
      new_post = Post.create!(title: 'New Post', content: 'Content', user: user1)
      Tagging.create!(tag: tag_ruby, taggable: new_post)

      result = serializer.serialize([post1, new_post], {}, includes: ['tags'])

      # Should include all posts and their tags without duplication
      tag_items = result[:included].select { |item| item[:type] == 'tags' }
      tag_names = tag_items.map { |tag| tag[:attributes]['name'] }

      # ruby tag should appear only once even though it's on multiple posts
      expect(tag_names.count('ruby')).to eq(1)
      expect(tag_names).to include('ruby', 'testing')
    end
  end
end
