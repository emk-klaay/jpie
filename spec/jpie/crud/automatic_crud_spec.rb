# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'JPie Automatic CRUD Handling' do
  describe 'Resource Creation' do
    it_behaves_like 'automatic author assignment', :post, {
      title: 'Auto-assigned Post',
      content: 'This post should have author auto-assigned'
    }
  end

  describe 'Standard CRUD Operations' do
    it_behaves_like 'standard CRUD operations', :post, {
      title: 'Test Post',
      content: 'Test content'
    }
  end

  describe 'Advanced CRUD Features' do
    let(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
    let(:post) { Post.create!(title: 'Test Post', content: 'Test content', user: user) }
    let(:controller_class) { create_test_controller('PostsController') }
    let(:controller) { controller_class.new }

    before do
      # Store user in instance variable to avoid closure issues
      @test_user = user
      controller.define_singleton_method(:current_user) { @test_user }
    end

    describe 'Include relationships' do
      it 'includes related resources' do
        controller.params = { id: post.id.to_s, include: 'user' }
        controller.show

        expect(controller.last_render[:status]).to eq(:ok)

        result = controller.last_render[:json]
        included_users = result[:included].select { |r| r[:type] == 'users' }
        expect(included_users.size).to eq(1)
        expect(included_users.first[:id]).to eq(user.id.to_s)
      end
    end

    describe 'Error handling' do
      it 'handles validation errors gracefully' do
        invalid_params = {
          data: {
            type: 'posts',
            attributes: {
              title: '', # Invalid empty title
              content: 'Content'
            }
          }
        }

        controller.request.set_body(invalid_params.to_json)
        controller.request.set_method('POST')
        controller.request.content_type = 'application/vnd.api+json'

        expect { controller.create }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'handles not found errors' do
        controller.params = { id: '999999' }

        expect { controller.show }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe 'Bulk operations' do
      it 'handles multiple resources in index' do
        # Create multiple posts
        3.times do |i|
          Post.create!(title: "Post #{i}", content: "Content #{i}", user: user)
        end

        controller.index

        expect(controller.last_render[:status]).to eq(:ok)

        result = controller.last_render[:json]
        expect(result[:data].size).to be >= 3
      end
    end
  end
end
