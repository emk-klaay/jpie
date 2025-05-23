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
  before do
    # Define mock classes for PostsController test
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
  end

  # Test controller that should automatically infer PostResource from its name
  let(:controller_class) do
    Class.new(ApplicationController) do
      include JPie::Controller

      def self.name
        'PostsController'
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

  describe 'resource inference' do
    it 'automatically infers PostResource from PostsController' do
      expect(controller.resource_class).to eq(PostResource)
    end

    it 'has access to Post model through the resource' do
      expect(controller.send(:model_class)).to eq(Post)
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
end
