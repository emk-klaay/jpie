# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'JPie Automatic CRUD Handling', type: :request do
  let!(:user) { User.create!(name: 'Test User', email: 'test@example.com') }

  # Mock current_user for authentication
  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  describe 'Automatic Author Assignment' do
    context 'when creating a post' do
      it 'automatically assigns current_user as author without controller override' do
        post_params = {
          data: {
            type: 'posts',
            attributes: {
              title: 'Auto-assigned Post',
              content: 'This post should have author auto-assigned'
            }
          }
        }

        post '/posts',
             params: post_params.to_json,
             headers: { 'Content-Type' => 'application/vnd.api+json' }

        expect(response).to have_http_status(:created)
        
        response_data = JSON.parse(response.body)
        created_post = Post.find(response_data['data']['id'])
        
        # Author should be automatically assigned from current_user
        expect(created_post.author).to eq(user)
        expect(created_post.title).to eq('Auto-assigned Post')
      end
    end

    context 'when creating an article' do
      it 'automatically assigns current_user as author' do
        article_params = {
          data: {
            type: 'articles',
            attributes: {
              title: 'Auto-assigned Article',
              body: 'This article should have author auto-assigned'
            }
          }
        }

        post '/articles',
             params: article_params.to_json,
             headers: { 'Content-Type' => 'application/vnd.api+json' }

        expect(response).to have_http_status(:created)
        
        created_article = Article.last
        expect(created_article.author).to eq(user)
        expect(created_article.title).to eq('Auto-assigned Article')
      end
    end

    context 'when creating a video' do
      it 'automatically assigns current_user as author' do
        video_params = {
          data: {
            type: 'videos',
            attributes: {
              title: 'Auto-assigned Video',
              url: 'https://example.com/auto-video'
            }
          }
        }

        post '/videos',
             params: video_params.to_json,
             headers: { 'Content-Type' => 'application/vnd.api+json' }

        expect(response).to have_http_status(:created)
        
        created_video = Video.last
        expect(created_video.author).to eq(user)
        expect(created_video.title).to eq('Auto-assigned Video')
      end
    end
  end

  describe 'Standard CRUD Operations' do
    let!(:post) { Post.create!(title: 'Test Post', content: 'Test content', author: user) }
    let!(:article) { Article.create!(title: 'Test Article', body: 'Test body', author: user) }

    describe 'GET (Read) operations' do
      it 'retrieves individual post' do
        get "/posts/#{post.id}",
            headers: { 'Accept' => 'application/vnd.api+json' }

        expect(response).to have_http_status(:ok)
        
        response_data = JSON.parse(response.body)
        expect(response_data['data']['id']).to eq(post.id.to_s)
        expect(response_data['data']['type']).to eq('posts')
        expect(response_data['data']['attributes']['title']).to eq('Test Post')
      end

      it 'retrieves collection of posts' do
        get '/posts',
            headers: { 'Accept' => 'application/vnd.api+json' }

        expect(response).to have_http_status(:ok)
        
        response_data = JSON.parse(response.body)
        expect(response_data['data']).to be_an(Array)
        expect(response_data['data'].size).to be >= 1
      end

      it 'includes related resources' do
        get "/posts/#{post.id}?include=author",
            headers: { 'Accept' => 'application/vnd.api+json' }

        expect(response).to have_http_status(:ok)
        
        response_data = JSON.parse(response.body)
        included_users = response_data['included'].select { |r| r['type'] == 'users' }
        expect(included_users.size).to eq(1)
        expect(included_users.first['id']).to eq(user.id.to_s)
      end
    end

    describe 'PATCH (Update) operations' do
      it 'updates post without affecting author' do
        update_params = {
          data: {
            id: post.id.to_s,
            type: 'posts',
            attributes: {
              title: 'Updated Title',
              content: 'Updated content'
            }
          }
        }

        patch "/posts/#{post.id}",
              params: update_params.to_json,
              headers: { 'Content-Type' => 'application/vnd.api+json' }

        expect(response).to have_http_status(:ok)
        
        post.reload
        expect(post.title).to eq('Updated Title')
        expect(post.content).to eq('Updated content')
        # Author should remain unchanged
        expect(post.author).to eq(user)
      end

      it 'updates article attributes' do
        update_params = {
          data: {
            id: article.id.to_s,
            type: 'articles',
            attributes: {
              title: 'Updated Article Title'
            }
          }
        }

        patch "/articles/#{article.id}",
              params: update_params.to_json,
              headers: { 'Content-Type' => 'application/vnd.api+json' }

        expect(response).to have_http_status(:ok)
        
        article.reload
        expect(article.title).to eq('Updated Article Title')
        expect(article.author).to eq(user)
      end
    end

    describe 'DELETE operations' do
      it 'deletes post successfully' do
        expect {
          delete "/posts/#{post.id}",
                 headers: { 'Accept' => 'application/vnd.api+json' }
        }.to change(Post, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end

      it 'deletes article successfully' do
        expect {
          delete "/articles/#{article.id}",
                 headers: { 'Accept' => 'application/vnd.api+json' }
        }.to change(Article, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end
  end

  describe 'Validation Handling' do
    it 'returns validation errors for invalid post' do
      invalid_params = {
        data: {
          type: 'posts',
          attributes: {
            title: '', # Invalid: empty title
            content: 'Some content'
          }
        }
      }

      post '/posts',
           params: invalid_params.to_json,
           headers: { 'Content-Type' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:unprocessable_entity)
      
      response_data = JSON.parse(response.body)
      expect(response_data['errors']).to be_present
      
      # Should contain validation error for title
      title_errors = response_data['errors'].select { |e| e['source']&.dig('pointer') == '/data/attributes/title' }
      expect(title_errors).to be_present
    end

    it 'returns validation errors for invalid article' do
      invalid_params = {
        data: {
          type: 'articles',
          attributes: {
            title: 'Valid Title',
            body: '' # Invalid: empty body
          }
        }
      }

      post '/articles',
           params: invalid_params.to_json,
           headers: { 'Content-Type' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:unprocessable_entity)
      
      response_data = JSON.parse(response.body)
      expect(response_data['errors']).to be_present
    end
  end

  describe 'Filtering and Sorting' do
    let!(:post1) { Post.create!(title: 'Alpha Post', content: 'Content A', author: user) }
    let!(:post2) { Post.create!(title: 'Beta Post', content: 'Content B', author: user) }

    it 'handles sorting automatically' do
      get '/posts?sort=title',
          headers: { 'Accept' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:ok)
      
      response_data = JSON.parse(response.body)
      titles = response_data['data'].map { |p| p['attributes']['title'] }
      expect(titles).to eq(titles.sort)
    end

    it 'handles reverse sorting' do
      get '/posts?sort=-title',
          headers: { 'Accept' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:ok)
      
      response_data = JSON.parse(response.body)
      titles = response_data['data'].map { |p| p['attributes']['title'] }
      expect(titles).to eq(titles.sort.reverse)
    end
  end

  describe 'Pagination' do
    before do
      # Create multiple posts for pagination testing
      10.times do |i|
        Post.create!(title: "Post #{i}", content: "Content #{i}", author: user)
      end
    end

    it 'handles pagination automatically' do
      get '/posts?page[number]=1&page[size]=5',
          headers: { 'Accept' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:ok)
      
      response_data = JSON.parse(response.body)
      expect(response_data['data'].size).to eq(5)
      expect(response_data['meta']).to include('pagination')
    end
  end

  describe 'Error Handling' do
    it 'returns 404 for non-existent resource' do
      get '/posts/99999',
          headers: { 'Accept' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:not_found)
      
      response_data = JSON.parse(response.body)
      expect(response_data['errors']).to be_present
    end

    it 'returns 422 for update with invalid data' do
      update_params = {
        data: {
          id: post.id.to_s,
          type: 'posts',
          attributes: {
            title: '' # Invalid: empty title
          }
        }
      }

      patch "/posts/#{post.id}",
            params: update_params.to_json,
            headers: { 'Content-Type' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'Content Type Handling' do
    it 'requires proper JSON:API content type for POST' do
      post_params = {
        data: {
          type: 'posts',
          attributes: {
            title: 'Test Post',
            content: 'Test content'
          }
        }
      }

      # Send without proper content type
      post '/posts',
           params: post_params.to_json,
           headers: { 'Content-Type' => 'application/json' } # Wrong content type

      expect(response).to have_http_status(:unsupported_media_type)
    end

    it 'accepts proper JSON:API content type' do
      post_params = {
        data: {
          type: 'posts',
          attributes: {
            title: 'Test Post',
            content: 'Test content'
          }
        }
      }

      post '/posts',
           params: post_params.to_json,
           headers: { 'Content-Type' => 'application/vnd.api+json' }

      expect(response).to have_http_status(:created)
    end
  end
end 