# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'JPie Polymorphic CRUD Handling' do
  # Test models for polymorphic associations
  let!(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let!(:post) { Post.create!(title: 'Test Post', content: 'Test content', author: user) }
  let!(:article) { Article.create!(title: 'Test Article', body: 'Test body', author: user) }
  let!(:video) { Video.create!(title: 'Test Video', url: 'https://example.com/video', author: user) }

  describe 'Polymorphic Comment Creation' do
    let(:comments_controller_class) { create_test_controller('CommentsController') }
    let(:comments_controller) { comments_controller_class.new }

    it 'creates comment with post as commentable' do
      request_body = {
        data: {
          type: 'comments',
          attributes: {
            content: 'Great post!'
          }
        }
      }

      comments_controller.request.set_method('POST')
      comments_controller.request.set_body(request_body.to_json)
      
      # Mock the creation to set polymorphic association
      allow(Comment).to receive(:create!).and_return(
        Comment.create!(content: 'Great post!', commentable: post, author: user)
      )
      
      comments_controller.create

      expect(comments_controller.last_render[:status]).to eq(:created)

      # Verify the comment was created with correct associations
      comment = Comment.last
      expect(comment.commentable).to eq(post)
      expect(comment.commentable_type).to eq('Post')
      expect(comment.author).to eq(user)
      expect(comment.content).to eq('Great post!')
    end
  end

  describe 'Polymorphic Serialization' do
    let(:serializer) { JPie::Serializer.new(CommentResource) }

    context 'when serializing comments with different commentable types' do
      let!(:post_comment) { Comment.create!(content: 'Post comment', commentable: post, author: user) }
      let!(:article_comment) { Comment.create!(content: 'Article comment', commentable: article, author: user) }
      let!(:video_comment) { Comment.create!(content: 'Video comment', commentable: video, author: user) }

      it 'correctly serializes all comment types' do
        comments = [post_comment, article_comment, video_comment]
        result = serializer.serialize(comments)

        expect(result[:data].size).to eq(3)
        
        # Verify all comments are properly serialized
        contents = result[:data].map { |c| c[:attributes]['content'] }
        expect(contents).to include('Post comment', 'Article comment', 'Video comment')
      end

      it 'includes polymorphic commentables when requested' do
        result = serializer.serialize(post_comment, {}, includes: ['commentable'])

        expect(result[:included]).to be_present
        
        included_post = result[:included].find { |item| item[:type] == 'posts' }
        expect(included_post).to be_present
        expect(included_post[:id]).to eq(post.id.to_s)
        expect(included_post[:attributes]['title']).to eq('Test Post')
      end

      it 'includes different polymorphic types correctly' do
        result = serializer.serialize([post_comment, article_comment, video_comment], {}, includes: ['commentable'])

        expect(result[:included]).to be_present
        
        # Should include all three different commentable types
        included_types = result[:included].map { |item| item[:type] }.uniq.sort
        expect(included_types).to contain_exactly('articles', 'posts', 'videos')
      end
    end
  end
end
