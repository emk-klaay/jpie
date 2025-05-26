# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'JPie Manual CRUD Instance Methods' do
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let(:post) { Post.create!(title: 'Test Post', content: 'Test content', user: user) }

  # Create a controller that uses manual methods instead of automatic ones
  let(:manual_controller_class) do
    create_test_controller('ManualCrudController').tap do |klass|
      # Override to use PostResource instead of inferring from controller name
      klass.define_method(:resource_class) { PostResource }
      klass.define_method(:model_class) { Post }
      klass.define_method(:current_user) { @current_user }
      klass.define_method(:current_user=) { |user| @current_user = user }
    end
  end

  let(:controller) { manual_controller_class.new }

  before do
    controller.current_user = user
  end

  describe 'manual #index method' do
    it 'renders all resources using instance method' do
      controller.index

      expect(controller.last_render[:json][:data]).to be_an(Array)
      expect(controller.last_render[:status]).to eq(:ok)
      expect(controller.last_render[:content_type]).to eq('application/vnd.api+json')
    end

    it 'applies sorting when sort parameter is provided' do
      controller.params = { sort: 'title' }
      controller.index

      expect(controller.last_render[:json][:data]).to be_an(Array)
    end

    it 'applies pagination when pagination parameters are provided' do
      # Create multiple posts for pagination
      3.times { |i| Post.create!(title: "Post #{i}", content: "Content #{i}", user: user) }

      controller.params = { page: '1', per_page: '2' }
      controller.index

      result = controller.last_render[:json]
      expect(result[:data]).to be_an(Array)
      expect(result[:data].length).to eq(2)
      expect(result[:meta][:pagination][:page]).to eq(1)
      expect(result[:meta][:pagination][:per_page]).to eq(2)
    end
  end

  describe 'manual #show method' do
    it 'renders a single resource using instance method' do
      controller.params = { id: post.id.to_s }
      controller.show

      expect(controller.last_render[:json][:data]).to be_a(Hash)
      expect(controller.last_render[:json][:data][:id]).to eq(post.id.to_s)
      expect(controller.last_render[:status]).to eq(:ok)
    end

    it 'includes related resources when include parameter is provided' do
      controller.params = { id: post.id.to_s, include: 'user' }
      controller.show

      result = controller.last_render[:json]
      expect(result[:data]).to be_a(Hash)
      expect(result[:included]).to be_an(Array)
      expect(result[:included].first[:type]).to eq('users')
    end
  end

  describe 'manual #create method' do
    it 'creates a new resource using instance method' do
      create_params = {
        data: {
          type: 'posts',
          attributes: {
            title: 'New Post',
            content: 'New content'
          }
        }
      }

      controller.request.body = create_params.to_json
      controller.request.method = 'POST'
      controller.request.content_type = 'application/vnd.api+json'

      expect { controller.create }.to change(Post, :count).by(1)

      expect(controller.last_render[:status]).to eq(:created)
      expect(controller.last_render[:json][:data][:attributes]['title']).to eq('New Post')
    end

    it 'validates JSON:API request format' do
      invalid_params = { invalid: 'data' }

      controller.request.body = invalid_params.to_json
      controller.request.method = 'POST'
      controller.request.content_type = 'application/vnd.api+json'

      expect { controller.create }.to raise_error(JPie::Errors::BadRequestError)
    end
  end

  describe 'manual #update method' do
    it 'updates an existing resource using instance method' do
      update_params = {
        data: {
          id: post.id.to_s,
          type: 'posts',
          attributes: {
            title: 'Updated Title'
          }
        }
      }

      controller.params = { id: post.id.to_s }
      controller.request.body = update_params.to_json
      controller.request.method = 'PATCH'
      controller.request.content_type = 'application/vnd.api+json'

      controller.update

      expect(controller.last_render[:status]).to eq(:ok)
      expect(controller.last_render[:json][:data][:attributes]['title']).to eq('Updated Title')

      post.reload
      expect(post.title).to eq('Updated Title')
    end

    it 'validates JSON:API request format for updates' do
      invalid_params = { invalid: 'data' }

      controller.params = { id: post.id.to_s }
      controller.request.body = invalid_params.to_json
      controller.request.method = 'PATCH'
      controller.request.content_type = 'application/vnd.api+json'

      expect { controller.update }.to raise_error(JPie::Errors::BadRequestError)
    end
  end

  describe 'manual #destroy method' do
    it 'destroys a resource using instance method' do
      post_id = post.id
      controller.params = { id: post_id.to_s }

      expect { controller.destroy }.to change(Post, :count).by(-1)

      expect(controller.last_head).to eq(:no_content)
      expect(Post.find_by(id: post_id)).to be_nil
    end
  end

  describe 'private #apply_pagination method' do
    let(:posts_scope) { Post.all }

    it 'applies pagination when per_page is provided' do
      # Create test data
      5.times { |i| Post.create!(title: "Post #{i}", content: "Content #{i}", user: user) }

      pagination_params = { page: 2, per_page: 2 }
      paginated_scope = controller.send(:apply_pagination, posts_scope, pagination_params)

      # Check that LIMIT and OFFSET are applied
      expect(paginated_scope.limit_value).to eq(2)
      expect(paginated_scope.offset_value).to eq(2) # (page - 1) * per_page = (2 - 1) * 2 = 2
    end

    it 'returns original scope when per_page is not provided' do
      pagination_params = { page: 2 }
      result = controller.send(:apply_pagination, posts_scope, pagination_params)

      expect(result).to eq(posts_scope)
    end

    it 'defaults to page 1 when page is not provided' do
      pagination_params = { per_page: 3 }
      paginated_scope = controller.send(:apply_pagination, posts_scope, pagination_params)

      expect(paginated_scope.limit_value).to eq(3)
      expect(paginated_scope.offset_value).to eq(0) # (1 - 1) * 3 = 0
    end
  end
end
