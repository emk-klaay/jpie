# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Deep Nesting Evaluation' do
  # Set up complex test data with multiple levels of relationships
  let!(:user1) { User.create!(name: 'Alice', email: 'alice@example.com') }
  let!(:user2) { User.create!(name: 'Bob', email: 'bob@example.com') }
  let!(:user3) { User.create!(name: 'Charlie', email: 'charlie@example.com') }

  let!(:tag1) { Tag.create!(name: 'Ruby') }
  let!(:tag2) { Tag.create!(name: 'Rails') }

  let!(:post1) { Post.create!(title: 'Post 1', content: 'Content 1', user: user1) }
  let!(:post2) { Post.create!(title: 'Post 2', content: 'Content 2', user: user2) }

  let!(:tagging1) { Tagging.create!(tag: tag1, taggable: post1) }
  let!(:tagging2) { Tagging.create!(tag: tag2, taggable: post1) }

  let!(:comment1) { Comment.create!(content: 'Comment 1', user: user2, post: post1) }
  let!(:comment2) { Comment.create!(content: 'Comment 2', user: user3, post: post1) }
  let!(:reply1) { Comment.create!(content: 'Reply 1', user: user1, post: post1, parent_comment: comment1) }
  let!(:reply2) { Comment.create!(content: 'Reply 2', user: user2, post: post1, parent_comment: comment1) }

  let!(:like1) { Like.create!(user: user1, comment: comment1) }
  let!(:like2) { Like.create!(user: user3, comment: comment1) }
  let!(:like3) { Like.create!(user: user2, comment: reply1) }

  describe 'Arbitrary depth nested includes' do
    let(:serializer) { JPie::Serializer.new(PostResource) }

    context 'with 2-level nesting' do
      it 'supports user.comments include' do
        result = serializer.serialize(post1, {}, includes: ['user.comments'])

        expect(result[:included]).to be_present
        user_items = result[:included].select { |item| item[:type] == 'users' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }

        expect(user_items.length).to eq(1)
        expect(comment_items.length).to eq(1) # Alice has 1 comment (reply1)
      end
    end

    context 'with 3-level nesting' do
      it 'supports user.comments.likes include' do
        result = serializer.serialize(post1, {}, includes: ['user.comments.likes'])

        expect(result[:included]).to be_present
        user_items = result[:included].select { |item| item[:type] == 'users' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }
        like_items = result[:included].select { |item| item[:type] == 'likes' }

        expect(user_items.length).to eq(1) # Alice (post author)
        expect(comment_items.length).to eq(1) # Alice's comments
        expect(like_items.length).to eq(1) # Likes on Alice's comments (reply1 has 1 like)
      end

      it 'supports user.comments.replies include' do
        result = serializer.serialize(post1, {}, includes: ['user.comments.replies'])

        expect(result[:included]).to be_present
        user_items = result[:included].select { |item| item[:type] == 'users' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }

        expect(user_items.length).to eq(1) # Alice (post author)
        # Should include Alice's original comments + any replies to those comments
        expect(comment_items.length).to be >= 1
      end
    end

    context 'with 4-level nesting' do
      it 'supports user.comments.likes.user include' do
        result = serializer.serialize(post1, {}, includes: ['user.comments.likes.user'])

        expect(result[:included]).to be_present
        user_items = result[:included].select { |item| item[:type] == 'users' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }
        like_items = result[:included].select { |item| item[:type] == 'likes' }

        # Should include post author + users who liked the post author's comments
        expect(user_items.length).to be >= 1
        expect(comment_items.length).to be >= 1
        expect(like_items.length).to be >= 1
      end

      it 'supports user.comments.replies.likes include' do
        result = serializer.serialize(post1, {}, includes: ['user.comments.replies.likes'])

        expect(result[:included]).to be_present

        # This tests very deep nesting: post -> user -> comments -> replies -> likes
        types_included = result[:included].map { |item| item[:type] }.uniq.sort
        expect(types_included).to include('users', 'comments')

        # Should handle the full chain without errors
        expect(result[:included]).to be_an(Array)
      end
    end

    context 'with multiple parallel deep includes' do
      it 'supports complex parallel nesting like user.comments.likes,user.comments.replies' do
        includes = ['user.comments.likes', 'user.comments.replies']
        result = serializer.serialize(post1, {}, includes: includes)

        expect(result[:included]).to be_present

        # Should include data from both parallel nested paths
        user_items = result[:included].select { |item| item[:type] == 'users' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }
        result[:included].select { |item| item[:type] == 'likes' }

        expect(user_items.length).to be >= 1
        expect(comment_items.length).to be >= 1

        # Should not duplicate resources
        unique_users = user_items.map { |u| u[:id] }.uniq
        expect(unique_users.length).to eq(user_items.length)
      end

      it 'supports mixed depth includes like user,user.comments,user.comments.likes' do
        includes = ['user', 'user.comments', 'user.comments.likes']
        result = serializer.serialize(post1, {}, includes: includes)

        expect(result[:included]).to be_present

        # Should include all levels without duplication
        user_items = result[:included].select { |item| item[:type] == 'users' }
        expect(user_items.map { |u| u[:id] }.uniq.length).to eq(user_items.length)
      end
    end

    context 'with very deep nesting (5+ levels)' do
      it 'supports extremely deep nesting like user.comments.replies.likes.user' do
        includes = ['user.comments.replies.likes.user']

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
        result = serializer.serialize(post1, {}, includes: ['user.nonexistent.comments'])

        # Should include the user but stop at the non-existent relationship
        expect(result[:included]).to be_present
        user_items = result[:included].select { |item| item[:type] == 'users' }
        expect(user_items.length).to eq(1)

        # Should not include comments since the chain is broken
        comment_items = result[:included].select { |item| item[:type] == 'comments' }
        expect(comment_items.length).to eq(0)
      end

      it 'handles non-existent final relationship' do
        result = serializer.serialize(post1, {}, includes: ['user.comments.nonexistent'])

        # Should include user and comments but ignore the non-existent final part
        user_items = result[:included].select { |item| item[:type] == 'users' }
        comment_items = result[:included].select { |item| item[:type] == 'comments' }

        expect(user_items.length).to eq(1)
        expect(comment_items.length).to be >= 1
      end
    end

    context 'with circular relationships' do
      it 'handles potential circular references without infinite recursion' do
        # comment.user.comments could potentially create a circle
        includes = ['comments.user.comments']

        expect do
          result = serializer.serialize(post1, {}, includes: includes)
          expect(result[:included]).to be_an(Array)
        end.not_to raise_error
      end
    end

    context 'with empty relationships' do
      let!(:post_no_comments) { Post.create!(title: 'No Comments', content: 'Content', user: user1) }

      it 'handles empty intermediate relationships gracefully' do
        result = serializer.serialize(post_no_comments, {}, includes: ['comments.likes'])

        # Should not error even though there are no comments to get likes from
        expect(result[:included]).to be_an(Array)
        expect(result[:included]).to be_empty
        comment_items = result[:included].select { |item| item[:type] == 'comments' }
        like_items = result[:included].select { |item| item[:type] == 'likes' }

        expect(comment_items.length).to eq(0)
        expect(like_items.length).to eq(0)
      end
    end
  end

  describe 'Performance and deduplication' do
    let(:serializer) { JPie::Serializer.new(PostResource) }

    it 'properly deduplicates resources across multiple nested paths' do
      # Both paths should include the same users but they should only appear once
      includes = ['user.comments.user', 'comments.user']
      result = serializer.serialize(post1, {}, includes: includes)

      user_items = result[:included].select { |item| item[:type] == 'users' }
      user_ids = user_items.map { |u| u[:id] }

      # Should not have duplicate users
      expect(user_ids.uniq.length).to eq(user_ids.length)
    end

    it 'handles complex scenarios with multiple resources and deep nesting efficiently' do
      posts = [post1, post2]
      includes = ['user.comments.likes.user', 'comments.user.posts']

      # Should complete without timeout or excessive memory usage
      start_time = Time.current
      result = serializer.serialize(posts, {}, includes: includes)
      end_time = Time.current

      expect(end_time - start_time).to be < 5.seconds # Should be much faster
      expect(result[:included]).to be_an(Array)
      expect(result[:included].length).to be > 0
    end
  end
end
