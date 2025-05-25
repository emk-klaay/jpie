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

        # Should not expose taggings
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
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

      it 'supports semantic relationship names' do
        result = serializer.serialize(tag_ruby, {}, includes: %w[tagged_posts tagged_comments])

        expect(result[:included]).to be_present
        post_items = result[:included].select { |item| item[:type] == 'posts' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }

        expect(post_items.count).to eq(1) # post1 has ruby tag
        expect(comment_items.count).to eq(1) # comment1 has ruby tag

        # Should not expose taggings
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end

      it 'supports deep polymorphic includes through clean relationships' do
        # Include the tag's posts/comments and their users
        result = serializer.serialize(tag_ruby, {}, includes: ['posts.user', 'comments.user'])

        expect(result[:included]).to be_present

        post_items = result[:included].select { |item| item[:type] == 'posts' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }
        user_items = result[:included].select { |item| item[:type] == 'users' }

        expect(post_items.count).to eq(1) # post1
        expect(comment_items.count).to eq(1) # comment1
        expect(user_items.count).to eq(2) # user1 (post author) and user2 (comment author)

        # Should not expose taggings
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end

      it 'supports parallel polymorphic paths with proper deduplication' do
        # Multiple paths that might include the same resources
        includes = ['posts.user', 'comments.user']
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

        # Should not expose taggings
        tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
        expect(tagging_items).to be_empty
      end
    end
  end

  describe 'Multiple polymorphic includes in a single request' do
    let(:serializer) { JPie::Serializer.new(PostResource) }

    context 'when requesting tags,comments,comments.tags' do
      let(:includes) { ['tags', 'comments', 'comments.tags'] }

      it 'includes all requested resources without duplicates' do
        result = serializer.serialize(post1, {}, includes: includes)

        expect(result[:included]).to be_present

        # Should include post tags
        post_tag_items = result[:included].select { |item| item[:type] == 'tags' }
        expect(post_tag_items.count).to eq(3) # ruby (shared), testing (post), api (reply)

        # Should include comments
        comment_items = result[:included].select { |item| item[:type] == 'comments' }
        expect(comment_items.count).to eq(2) # comment1 and reply1

        # Verify tag names include both post tags and comment tags
        tag_names = post_tag_items.map { |tag| tag[:attributes]['name'] }
        expect(tag_names).to contain_exactly('ruby', 'testing', 'api')
      end

      it 'properly deduplicates tags that appear on both posts and comments' do
        result = serializer.serialize(post1, {}, includes: includes)

        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        tag_ids = tag_items.map { |tag| tag[:id] }

        # Should not have duplicate tag IDs
        expect(tag_ids.uniq.length).to eq(tag_ids.length)

        # Specifically check that ruby tag (which is on both post and comment) appears only once
        ruby_tags = tag_items.select { |tag| tag[:attributes]['name'] == 'ruby' }
        expect(ruby_tags.count).to eq(1)
      end
    end

    context 'when requesting multiple includes with overlap' do
      let(:includes) { ['tags', 'comments.tags', 'comments.user'] }

      it 'handles overlapping include paths efficiently' do
        result = serializer.serialize(post1, {}, includes: includes)

        expect(result[:included]).to be_present

        # Check that we have the expected resource types
        included_types = result[:included].map { |item| item[:type] }.uniq.sort
        expect(included_types).to contain_exactly('comments', 'tags', 'users')

        # Verify we have proper counts without duplication
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }
        user_items = result[:included].select { |item| item[:type] == 'users' }

        expect(tag_items.count).to eq(3) # ruby, testing, api
        expect(comment_items.count).to eq(2) # comment1, reply1
        expect(user_items.count).to eq(2) # user1, user2
      end
    end

    context 'when serializing multiple posts with polymorphic includes' do
      let(:includes) { ['tags', 'comments', 'comments.tags'] }

      it 'includes resources from all posts without duplication' do
        result = serializer.serialize([post1, post2], {}, includes: includes)

        expect(result[:included]).to be_present

        # Should include tags from both posts and their comments
        tag_items = result[:included].select { |item| item[:type] == 'tags' }
        tag_names = tag_items.map { |tag| tag[:attributes]['name'] }.sort
        expect(tag_names).to contain_exactly('api', 'rails', 'ruby', 'testing')

        # Should include comments from both posts
        comment_items = result[:included].select { |item| item[:type] == 'comments' }
        expect(comment_items.count).to eq(3) # comment1, comment2, reply1

        # Verify no duplicate resources
        tag_ids = tag_items.map { |tag| tag[:id] }
        comment_ids = comment_items.map { |comment| comment[:id] }

        expect(tag_ids.uniq.length).to eq(tag_ids.length)
        expect(comment_ids.uniq.length).to eq(comment_ids.length)
      end
    end

    context 'with very complex polymorphic include paths' do
      let(:includes) { ['tags.posts.user', 'comments.tags.posts', 'user'] }

      it 'handles deeply nested polymorphic includes across multiple paths' do
        result = serializer.serialize(post1, {}, includes: includes)

        expect(result[:included]).to be_present

        # Should contain all the expected types
        included_types = result[:included].map { |item| item[:type] }.uniq.sort
        expect(included_types).to include('comments', 'posts', 'tags', 'users')

        # Verify deduplication works across complex paths
        user_items = result[:included].select { |item| item[:type] == 'users' }
        post_items = result[:included].select { |item| item[:type] == 'posts' }

        # Should not have duplicate users or posts
        user_ids = user_items.map { |u| u[:id] }
        post_ids = post_items.map { |p| p[:id] }

        expect(user_ids.uniq.length).to eq(user_ids.length)
        expect(post_ids.uniq.length).to eq(post_ids.length)
      end
    end
  end

  describe 'JSON:API compliance with polymorphic data - Clean API' do
    it 'produces valid JSON:API structure with clean polymorphic includes' do
      serializer = JPie::Serializer.new(TagResource)
      result = serializer.serialize(tag_ruby, {}, includes: %w[posts comments])

      # Should have proper JSON:API structure
      expect(result).to have_key(:data)
      expect(result).to have_key(:included)

      # Data should be a single tag
      expect(result[:data][:type]).to eq('tags')
      expect(result[:data][:attributes]['name']).to eq('ruby')

      # Included should contain only business objects, not join tables
      included_types = result[:included].map { |item| item[:type] }.uniq.sort
      expect(included_types).to contain_exactly('comments', 'posts')

      # Should not expose taggings
      tagging_items = result[:included].select { |item| item[:type] == 'taggings' }
      expect(tagging_items).to be_empty
    end

    it 'maintains proper resource linkage in polymorphic scenarios' do
      serializer = JPie::Serializer.new(PostResource)
      result = serializer.serialize(post1, {}, includes: ['tags', 'comments'])

      # Verify proper structure
      expect(result[:data][:type]).to eq('posts')
      expect(result[:included]).to be_an(Array)

      # All included items should have proper type and id
      result[:included].each do |item|
        expect(item).to have_key(:type)
        expect(item).to have_key(:id)
        expect(item).to have_key(:attributes)
      end
    end
  end
end 