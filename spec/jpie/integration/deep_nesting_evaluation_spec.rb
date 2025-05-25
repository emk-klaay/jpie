# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Deep Nesting Evaluation' do
  # Set up complex test data for deep nesting scenarios
  let!(:user1) { User.create!(name: 'Alice', email: 'alice@example.com') }
  let!(:user2) { User.create!(name: 'Bob', email: 'bob@example.com') }
  let!(:user3) { User.create!(name: 'Charlie', email: 'charlie@example.com') }

  let!(:tag1) { Tag.create!(name: 'ruby') }
  let!(:tag2) { Tag.create!(name: 'rails') }

  let!(:post1) { Post.create!(title: 'Post 1', content: 'Content 1', user: user1) }
  let!(:post2) { Post.create!(title: 'Post 2', content: 'Content 2', user: user2) }

  let!(:tagging1) { Tagging.create!(tag: tag1, taggable: post1) }
  let!(:tagging2) { Tagging.create!(tag: tag2, taggable: post1) }

  let!(:reply1) { Post.create!(title: 'Reply 1', content: 'Reply content 1', user: user2, parent_post: post1) }
  let!(:reply2) { Post.create!(title: 'Reply 2', content: 'Reply content 2', user: user3, parent_post: post1) }
  let!(:nested_reply1) do
    Post.create!(title: 'Nested Reply 1', content: 'Nested reply content 1', user: user1, parent_post: reply1)
  end
  let!(:nested_reply2) do
    Post.create!(title: 'Nested Reply 2', content: 'Nested reply content 2', user: user2, parent_post: reply1)
  end

  # Set up tags on replies for deeper nesting
  let!(:reply_tagging1) { Tagging.create!(tag: tag1, taggable: reply1) }
  let!(:reply_tagging2) { Tagging.create!(tag: tag2, taggable: nested_reply1) }

  describe 'Arbitrary depth nested includes' do
    let(:serializer) { JPie::Serializer.new(PostResource) }

    context 'with 2-level nesting' do
      it 'supports user.posts include' do
        result = serializer.serialize(post1, {}, includes: ['user.posts'])

        expect(result[:included]).to be_present
        user_items = result[:included].select { |item| item[:type] == 'users' }
        post_items = result[:included].select { |item| item[:type] == 'posts' && item[:id] != post1.id.to_s }

        expect(user_items.length).to eq(1)
        expect(post_items.length).to eq(1) # Alice has 1 other post (nested_reply1)
      end
    end

    context 'with 3-level nesting' do
      it 'supports user.posts.tags include' do
        result = serializer.serialize(post1, {}, includes: ['user.posts.tags'])

        expect(result[:included]).to be_present
        user_items = result[:included].select { |item| item[:type] == 'users' }
        post_items = result[:included].select { |item| item[:type] == 'posts' && item[:id] != post1.id.to_s }
        tag_items = result[:included].select { |item| item[:type] == 'tags' }

        expect(user_items.length).to eq(1) # Alice (post author)
        expect(post_items.length).to eq(1) # Alice's other posts
        # Tags on Alice's other posts (nested_reply1 has rails tag, and post1 has ruby and rails tags)
        expect(tag_items.length).to eq(2)
      end

      it 'supports user.posts.replies include' do
        result = serializer.serialize(post1, {}, includes: ['user.posts.replies'])

        expect(result[:included]).to be_present
        user_items = result[:included].select { |item| item[:type] == 'users' }
        post_items = result[:included].select { |item| item[:type] == 'posts' && item[:id] != post1.id.to_s }

        expect(user_items.length).to eq(1) # Alice (post author)
        # Should include Alice's posts + any replies to those posts
        expect(post_items.length).to be >= 1
      end
    end

    context 'with 4-level nesting' do
      it 'supports user.posts.tags.posts include' do
        result = serializer.serialize(post1, {}, includes: ['user.posts.tags.posts'])

        expect(result[:included]).to be_present
        user_items = result[:included].select { |item| item[:type] == 'users' }
        post_items = result[:included].select { |item| item[:type] == 'posts' && item[:id] != post1.id.to_s }
        tag_items = result[:included].select { |item| item[:type] == 'tags' }

        # Should include post author + posts that share tags with the post author's posts
        expect(user_items.length).to be >= 1
        expect(post_items.length).to be >= 1
        expect(tag_items.length).to be >= 1
      end

      it 'supports user.posts.replies.tags include' do
        result = serializer.serialize(post1, {}, includes: ['user.posts.replies.tags'])

        expect(result[:included]).to be_present

        # This tests very deep nesting: post -> user -> posts -> replies -> tags
        types_included = result[:included].map { |item| item[:type] }.uniq.sort
        expect(types_included).to include('users', 'posts')

        # Should handle the full chain without errors
        expect(result[:included]).to be_an(Array)
      end
    end

    context 'with multiple parallel deep includes' do
      it 'supports complex parallel nesting like user.posts.tags,user.posts.replies' do
        includes = ['user.posts.tags', 'user.posts.replies']
        result = serializer.serialize(post1, {}, includes: includes)

        expect(result[:included]).to be_present

        # Should include data from both parallel nested paths
        user_items = result[:included].select { |item| item[:type] == 'users' }
        post_items = result[:included].select { |item| item[:type] == 'posts' && item[:id] != post1.id.to_s }

        expect(user_items.length).to be >= 1
        expect(post_items.length).to be >= 1

        # Should not duplicate resources
        unique_users = user_items.map { |u| u[:id] }.uniq
        expect(unique_users.length).to eq(user_items.length)
      end

      it 'supports mixed depth includes like user,user.posts,user.posts.tags' do
        includes = ['user', 'user.posts', 'user.posts.tags']
        result = serializer.serialize(post1, {}, includes: includes)

        expect(result[:included]).to be_present

        # Should include all levels without duplication
        user_items = result[:included].select { |item| item[:type] == 'users' }
        expect(user_items.map { |u| u[:id] }.uniq.length).to eq(user_items.length)
      end
    end

    context 'with very deep nesting (5+ levels)' do
      it 'supports extremely deep nesting like user.posts.replies.tags.posts' do
        includes = ['user.posts.replies.tags.posts']

        # This should not cause stack overflow or infinite recursion
        expect do
          result = serializer.serialize(post1, {}, includes: includes)
          expect(result[:included]).to be_an(Array)
        end.not_to raise_error
      end
    end
  end

  describe 'Edge cases and error handling' do
    let(:serializer) { JPie::Serializer.new(PostResource) }

    context 'with non-existent relationships in chain' do
      it 'gracefully handles missing intermediate relationships' do
        # 'nonexistent' relationship doesn't exist on User
        result = serializer.serialize(post1, {}, includes: ['user.nonexistent.posts'])

        # Should include the user but stop at the non-existent relationship
        expect(result[:included]).to be_present
        user_items = result[:included].select { |item| item[:type] == 'users' }
        expect(user_items.length).to eq(1)

        # Should not include posts since the chain is broken
        post_items = result[:included].select { |item| item[:type] == 'posts' && item[:id] != post1.id.to_s }
        expect(post_items.length).to eq(0)
      end

      it 'handles non-existent final relationship' do
        result = serializer.serialize(post1, {}, includes: ['user.posts.nonexistent'])

        # Should include user and posts but ignore the non-existent final part
        user_items = result[:included].select { |item| item[:type] == 'users' }
        post_items = result[:included].select { |item| item[:type] == 'posts' && item[:id] != post1.id.to_s }

        expect(user_items.length).to eq(1)
        expect(post_items.length).to be >= 1
      end
    end

    context 'with circular relationships' do
      it 'handles potential circular references without infinite recursion' do
        # replies.user.posts could potentially create a circle
        includes = ['replies.user.posts']

        expect do
          result = serializer.serialize(post1, {}, includes: includes)
          expect(result[:included]).to be_an(Array)
        end.not_to raise_error
      end
    end

    context 'with empty relationships' do
      let!(:post_no_replies) { Post.create!(title: 'No Replies', content: 'Content', user: user1) }

      it 'handles empty intermediate relationships gracefully' do
        result = serializer.serialize(post_no_replies, {}, includes: ['replies.tags'])

        # Should not error even though there are no replies to get tags from
        expect(result[:included]).to be_an(Array)
        expect(result[:included]).to be_empty
        reply_items = result[:included].select { |item| item[:type] == 'posts' && item[:id] != post_no_replies.id.to_s }
        tag_items = result[:included].select { |item| item[:type] == 'tags' }

        expect(reply_items.length).to eq(0)
        expect(tag_items.length).to eq(0)
      end
    end
  end

  describe 'Performance and deduplication' do
    let(:serializer) { JPie::Serializer.new(PostResource) }

    it 'properly deduplicates resources across multiple nested paths' do
      # Both paths should include the same users but they should only appear once
      includes = ['user.posts.user', 'replies.user']
      result = serializer.serialize(post1, {}, includes: includes)

      user_items = result[:included].select { |item| item[:type] == 'users' }
      user_ids = user_items.map { |u| u[:id] }

      # Should not have duplicate users
      expect(user_ids.uniq.length).to eq(user_ids.length)
    end

    it 'handles large nested datasets efficiently' do
      # Create additional test data
      10.times do |i|
        reply = Post.create!(title: "Mass Reply #{i}", content: "Content #{i}", user: user2, parent_post: post1)
        Tagging.create!(tag: tag1, taggable: reply)
      end

      includes = ['replies.tags.posts']

      expect do
        result = serializer.serialize(post1, {}, includes: includes)
        expect(result[:included]).to be_an(Array)
        expect(result[:included].length).to be > 0
      end.not_to raise_error
    end
  end

  describe 'Complex real-world scenarios' do
    let(:serializer) { JPie::Serializer.new(PostResource) }

    it 'handles complex blog-like nested structures' do
      # Simulate a complex blog post with replies, tags, and cross-references
      includes = [
        'user',
        'tags',
        'replies',
        'replies.user',
        'replies.tags',
        'tags.posts.user'
      ]

      result = serializer.serialize(post1, {}, includes: includes)

      expect(result[:included]).to be_present

      # Should include all expected types
      types = result[:included].map { |item| item[:type] }.uniq.sort
      expect(types).to include('users', 'posts', 'tags')

      # Should properly deduplicate across all paths
      user_items = result[:included].select { |item| item[:type] == 'users' }
      post_items = result[:included].select { |item| item[:type] == 'posts' }
      tag_items = result[:included].select { |item| item[:type] == 'tags' }

      # Check for duplicates
      expect(user_items.map { |u| u[:id] }.uniq.length).to eq(user_items.length)
      expect(post_items.map { |p| p[:id] }.uniq.length).to eq(post_items.length)
      expect(tag_items.map { |t| t[:id] }.uniq.length).to eq(tag_items.length)
    end
  end
end
