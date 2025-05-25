# frozen_string_literal: true

module ControllerHelpers
  def mock_request_classes
    stub_const('MockRequest', create_mock_request_class)
    stub_const('MockBody', create_mock_body_class)
    stub_const('MockResponse', Class.new)
  end

  private

  def create_mock_request_class
    request_class = Class.new
    setup_mock_request_class(request_class)
    request_class
  end

  def setup_mock_request_class(request_class)
    request_class.attr_accessor :content_type
    add_request_initialization(request_class)
    add_request_body_methods(request_class)
    add_request_http_methods(request_class)
  end

  def add_request_initialization(request_class)
    request_class.define_method(:initialize) do
      @content_type = 'application/vnd.api+json'
      @method = 'GET'
      @body_content = '{}'
    end
  end

  def add_request_body_methods(request_class)
    request_class.define_method(:body) { MockBody.new(@body_content) }
    request_class.define_method(:body=) { |content| @body_content = content }
  end

  def add_request_http_methods(request_class)
    %w[POST PATCH PUT].each do |http_method|
      request_class.define_method("#{http_method.downcase}?") do
        @method == http_method
      end
    end
    request_class.define_method(:method=) { |method| @method = method.upcase }
  end

  def create_mock_body_class
    Class.new do
      def initialize(content = '{}')
        @content = content
        @position = 0
      end

      def read
        result = @content[@position..] || ''
        @position = @content.length
        result
      end

      def rewind
        @position = 0
      end
    end
  end

  def mock_application_controller
    return if defined?(ApplicationController)

    stub_const('ApplicationController', Class.new do
      def self.rescue_from(exception_class, with: nil)
        # Mock implementation for testing
      end

      def head(status)
        # Mock implementation
      end
    end)
  end

  def create_test_controller(name, resource_class = nil)
    setup_mock_classes
    build_controller_class(name, resource_class)
  end

  def setup_mock_classes
    mock_request_classes
    mock_application_controller
  end

  def build_controller_class(name, resource_class)
    controller_class = Class.new(ApplicationController)
    setup_controller_class(controller_class, name, resource_class)
    controller_class
  end

  def setup_controller_class(controller_class, name, resource_class)
    controller_class.include JPie::Controller
    controller_class.define_singleton_method(:name) { name }
    controller_class.define_method(:resource_class) { resource_class } if resource_class
    add_controller_methods(controller_class)
  end

  def add_controller_methods(controller_class)
    controller_class.attr_accessor :params, :request, :response
    controller_class.attr_reader :last_render, :last_head

    controller_class.define_method(:initialize) { setup_controller_defaults }
    controller_class.define_method(:render) { |options = {}| @last_render = options }
    controller_class.define_method(:head) { |status| @last_head = status }
    controller_class.define_method(:action_name) { 'show' }
    controller_class.define_method(:setup_controller_defaults) do
      @params = {}
      @request = MockRequest.new
      @response = MockResponse.new
    end
  end

  def expect_json_api_response(controller, expected_keys = [:data])
    expect(controller.last_render).to have_key(:json)
    expect(controller.last_render[:content_type]).to eq('application/vnd.api+json')

    expected_keys.each do |key|
      expect(controller.last_render[:json]).to have_key(key)
    end
  end
end

RSpec.configure do |config|
  config.include ControllerHelpers
end
