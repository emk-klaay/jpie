# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'JPie Polymorphic CRUD Handling', type: :request do
  # Test models for polymorphic associations
  let!(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let!(:post) { Post.create!(title: 'Test Post', content: 'Test content', author: user) }
  let!(:article) { Article.create!(title: 'Test Article', body: 'Test body', author: user) }
  let!(:video) { Video.create!(title: 'Test Video', url: 'https://example.com/video', author: user) }

  # Mock current_user for authentication
  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  describe 'Polymorphic Comment Creation' do
    context 'when creating comment on a post via nested route' do
      it 'automatically sets polymorphic association and author' do
        comment_params = {
          data: {
            type: 'comments',
            attributes: {
              content: 'Great post!'
            }
          }
        }

        post "/posts/#{post.id}/comments",
             params: comment_params.to_json,
             headers: { 'Content-Type' => 'application/vnd.api+json' }

        expect(response).to have_http_status(:created)

        response_data = JSON.parse(response.body)
        comment_id = response_data['data']['id']
        comment = Comment.find(comment_id)

        # Verify polymorphic association was set automatically
        expect(comment.commentable).to eq(post)
        expect(comment.commentable_type).to eq('Post')
        expect(comment.commentable_id).to eq(post.id)

        # Verify author was set automatically from current_user
        expect(comment.author).to eq(user)

        # Verify response format
        expect(response_data['data']['attributes']['content']).to eq('Great post!')
      end
    end

    context 'when creating comment on an article via nested route' do
      it 'automatically sets polymorphic association to article' do
        comment_params = {
          data: {
            type: 'comments',
            attributes: {
              content: 'Informative article!'
            }
          }
        }

        post "/articles/#{article.id}/comments",
             params: comment_params.to_json,
             headers: { 'Content-Type' => 'application/vnd.api+json' }

        expect(response).to have_http_status(:created)

        comment = Comment.last
        expect(comment.commentable).to eq(article)
        expect(comment.commentable_type).to eq('Article')
        expect(comment.author).to eq(user)
      end
    end

    context 'when creating comment on a video via nested route' do
      it 'automatically sets polymorphic association to video' do
        comment_params = {
          data: {
            type: 'comments',
            attributes: {
              content: 'Great video!'
            }
          }
        }

        post "/videos/#{video.id}/comments",
             params: comment_params.to_json,
             headers: { 'Content-Type' => 'application/vnd.api+json' }

        expect(response).to have_http_status(:created)

        comment = Comment.last
        expect(comment.commentable).to eq(video)
        expect(comment.commentable_type).to eq('Video')
        expect(comment.author).to eq(user)
      end
    end
  end

  describe 'Polymorphic Comment Updates' do
    let!(:comment) { Comment.create!(content: 'Original content', commentable: post, author: user) }

    it 'updates comment without affecting polymorphic associations' do
      update_params = {
        data: {
          id: comment.id.to_s,
          type: 'comments',
          attributes: {
            content: 'Updated content'
          }
        }
      }

      patch "/comments/#{comment.id}",
            params: update_params.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:ok)

      comment.reload
      expect(comment.content).to eq('Updated content')
      # Polymorphic associations should remain unchanged
      expect(comment.commentable).to eq(post)
      expect(comment.author).to eq(user)
    end
  end

  describe 'Polymorphic Association Queries' do
    let!(:post_comment) { Comment.create!(content: 'Post comment', commentable: post, author: user) }
    let!(:article_comment) { Comment.create!(content: 'Article comment', commentable: article, author: user) }
    let!(:video_comment) { Comment.create!(content: 'Video comment', commentable: video, author: user) }

    it 'retrieves comments for specific post' do
      get "/posts/#{post.id}/comments",
          headers: { 'Accept' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:ok)

      response_data = JSON.parse(response.body)
      expect(response_data['data'].size).to eq(1)
      expect(response_data['data'].first['attributes']['content']).to eq('Post comment')
    end

    it 'retrieves comments for specific article' do
      get "/articles/#{article.id}/comments",
          headers: { 'Accept' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:ok)

      response_data = JSON.parse(response.body)
      expect(response_data['data'].size).to eq(1)
      expect(response_data['data'].first['attributes']['content']).to eq('Article comment')
    end

    it 'retrieves comments for specific video' do
      get "/videos/#{video.id}/comments",
          headers: { 'Accept' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:ok)

      response_data = JSON.parse(response.body)
      expect(response_data['data'].size).to eq(1)
      expect(response_data['data'].first['attributes']['content']).to eq('Video comment')
    end
  end

  describe 'Polymorphic Include Support' do
    let!(:comment) { Comment.create!(content: 'Test comment', commentable: post, author: user) }

    it 'includes polymorphic commentable in comment response' do
      get "/comments/#{comment.id}?include=commentable",
          headers: { 'Accept' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:ok)

      response_data = JSON.parse(response.body)
      expect(response_data['included']).to be_present

      included_post = response_data['included'].find { |item| item['type'] == 'posts' }
      expect(included_post).to be_present
      expect(included_post['id']).to eq(post.id.to_s)
    end

    it 'includes author in polymorphic comment response' do
      get "/comments/#{comment.id}?include=author",
          headers: { 'Accept' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:ok)

      response_data = JSON.parse(response.body)
      expect(response_data['included']).to be_present

      included_user = response_data['included'].find { |item| item['type'] == 'users' }
      expect(included_user).to be_present
      expect(included_user['id']).to eq(user.id.to_s)
    end
  end

  describe 'Error Handling' do
    context 'when trying to create comment with invalid data' do
      it 'returns proper validation errors' do
        comment_params = {
          data: {
            type: 'comments',
            attributes: {
              content: '' # Invalid: empty content
            }
          }
        }

        post "/posts/#{post.id}/comments",
             params: comment_params.to_json,
             headers: { 'Content-Type' => 'application/vnd.api+json' }

        expect(response).to have_http_status(:unprocessable_entity)

        response_data = JSON.parse(response.body)
        expect(response_data['errors']).to be_present
      end
    end

    context 'when trying to create comment on non-existent post' do
      it 'returns not found error' do
        comment_params = {
          data: {
            type: 'comments',
            attributes: {
              content: 'This should fail'
            }
          }
        }

        post '/posts/99999/comments',
             params: comment_params.to_json,
             headers: { 'Content-Type' => 'application/vnd.api+json' }

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'Deletion Handling' do
    let!(:comment) { Comment.create!(content: 'To be deleted', commentable: post, author: user) }

    it 'deletes polymorphic comment successfully' do
      expect do
        delete "/comments/#{comment.id}",
               headers: { 'Accept' => 'application/vnd.api+json' }
      end.to change(Comment, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'Complex Polymorphic Scenarios' do
    context 'when comment belongs to different types of commentables' do
      let!(:post_comment) { Comment.create!(content: 'Post comment', commentable: post, author: user) }
      let!(:article_comment) { Comment.create!(content: 'Article comment', commentable: article, author: user) }
      let!(:video_comment) { Comment.create!(content: 'Video comment', commentable: video, author: user) }

      it 'correctly handles listing all comments regardless of commentable type' do
        get '/comments',
            headers: { 'Accept' => 'application/vnd.api+json' }

        expect(response).to have_http_status(:ok)

        response_data = JSON.parse(response.body)
        expect(response_data['data'].size).to eq(3)

        # Verify all comment types are included
        contents = response_data['data'].map { |c| c['attributes']['content'] }
        expect(contents).to include('Post comment', 'Article comment', 'Video comment')
      end
    end
  end
end
