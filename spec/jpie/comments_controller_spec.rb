# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'CommentsController' do
  before do
    # Define mock classes for CommentsController test
    stub_const('MockRequest', Class.new do
      def body
        MockBody.new
      end
    end)

    stub_const('MockBody', Class.new do
      def read
        '{}'
      end
    end)

    stub_const('MockResponse', Class.new)
    
    # Define a local base controller for this test
    stub_const('BaseController', Class.new do
      def self.rescue_from(exception_class, with: nil)
        # Mock implementation for testing
      end

      def head(status)
        # Mock implementation
      end
    end)
  end

  # Test controller that should automatically infer CommentResource from its name
  let(:controller_class) do
    Class.new(BaseController) do
      include JPie::Controller

      def self.name
        'CommentsController'
      end

      attr_accessor :params, :request, :response

      def initialize
        @params = {}
        @request = MockRequest.new
        @response = MockResponse.new
      end

      def render(options = {})
        @last_render = options
      end

      def action_name
        'test'
      end

      attr_reader :last_render
    end
  end

  let(:controller) { controller_class.new }
  let(:user) { User.create!(name: 'John Doe', email: 'john@example.com') }
  let(:post_instance) do
    Post.create!(
      title: 'Test Post',
      content: 'This is a test post content',
      user: user
    )
  end

  describe 'resource inference' do
    it 'automatically infers CommentResource from CommentsController' do
      expect(controller.resource_class).to eq(CommentResource)
    end

    it 'has access to Comment model through the resource' do
      expect(controller.send(:model_class)).to eq(Comment)
    end
  end

  describe 'CRUD methods' do
    it 'defines all CRUD methods', :aggregate_failures do
      expect(controller).to respond_to(:index)
      expect(controller).to respond_to(:show)
      expect(controller).to respond_to(:create)
      expect(controller).to respond_to(:update)
      expect(controller).to respond_to(:destroy)
    end
  end

  describe 'comment creation and relationships' do
    it 'can create comments with proper associations' do
      comment = Comment.create!(
        content: 'Test comment content',
        user: user,
        post: post_instance
      )

      resource = CommentResource.new(comment)
      
      expect(resource.content).to eq('Test comment content')
      expect(resource.user).to eq(user)
      expect(resource.post).to eq(post_instance)
    end
  end
end 