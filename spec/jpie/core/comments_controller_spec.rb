# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'CommentsController' do
  let(:controller_class) { create_test_controller('CommentsController') }
  let(:controller) { controller_class.new }
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let(:post) { Post.create!(title: 'Test Post', content: 'Test content', user: user) }
  let(:comment) { Comment.create!(content: 'Test comment', user: user, post: post) }

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
    before { comment } # Ensure comment exists

    it 'renders all comments' do
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
    it 'renders a single comment' do
      controller.params = { id: comment.id.to_s }
      controller.show

      expect_json_api_response(controller)
    end

    it 'returns hash data for show' do
      controller.params = { id: comment.id.to_s }
      controller.show

      expect(controller.last_render[:json][:data]).to be_a(Hash)
    end

    it 'returns ok status for show' do
      controller.params = { id: comment.id.to_s }
      controller.show

      expect(controller.last_render[:status]).to eq(:ok)
    end
  end

  describe '#destroy' do
    it 'returns no content status' do
      controller.params = { id: comment.id.to_s }
      controller.destroy

      expect(controller.last_head).to eq(:no_content)
    end
  end

  describe 'resource class inference' do
    it 'infers CommentResource from CommentsController' do
      expect(controller.send(:resource_class)).to eq(CommentResource)
    end
  end
end
