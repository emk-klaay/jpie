# frozen_string_literal: true

require 'spec_helper'

# Define ApplicationController for tests
class ApplicationController
  def self.rescue_from(exception_class, with: nil)
    # Mock implementation for testing
  end

  def head(status)
    # Mock implementation
  end
end

RSpec.describe 'PostsController' do
  let(:controller_class) { create_test_controller('PostsController') }
  let(:controller) { controller_class.new }
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let(:post) { Post.create!(title: 'Test Post', content: 'Test content', user: user) }

  describe 'CRUD operations' do
    it 'defines all CRUD methods', :aggregate_failures do
      expect(controller).to respond_to(:index)
      expect(controller).to respond_to(:show)
      expect(controller).to respond_to(:create)
      expect(controller).to respond_to(:update)
      expect(controller).to respond_to(:destroy)
    end
  end

  describe '#index' do
    before { post } # Ensure post exists

    it 'renders all posts' do
      controller.index
      expect_json_api_response(controller)
    end

    it 'returns array data for index' do
      controller.index
      expect(controller.last_render[:json][:data]).to be_an(Array)
    end

    it 'returns ok status for index' do
      controller.index
      expect(controller.last_render[:status]).to eq(:ok)
    end
  end

  describe '#show' do
    it 'renders a single post' do
      controller.params = { id: post.id.to_s }
      controller.show

      expect_json_api_response(controller)
    end

    it 'returns hash data for show' do
      controller.params = { id: post.id.to_s }
      controller.show

      expect(controller.last_render[:json][:data]).to be_a(Hash)
    end

    it 'returns ok status for show' do
      controller.params = { id: post.id.to_s }
      controller.show

      expect(controller.last_render[:status]).to eq(:ok)
    end
  end

  describe 'resource class inference' do
    it 'infers PostResource from PostsController' do
      expect(controller.send(:resource_class)).to eq(PostResource)
    end
  end
end
