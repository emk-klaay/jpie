module ControllerHelpers
  def mock_request_classes
    stub_const('MockRequest', Class.new do
      attr_accessor :content_type

      def initialize
        @content_type = 'application/vnd.api+json'
        @method = 'GET'
        @body_content = '{}'
      end

      def body
        MockBody.new(@body_content)
      end

      def set_body(content)
        @body_content = content
      end

      def post?
        @method == 'POST'
      end

      def patch?
        @method == 'PATCH'
      end

      def put?
        @method == 'PUT'
      end

      def set_method(method)
        @method = method.upcase
      end
    end)

    stub_const('MockBody', Class.new do
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
    end)

    stub_const('MockResponse', Class.new)
  end

  def mock_application_controller
    stub_const('ApplicationController', Class.new do
      def self.rescue_from(exception_class, with: nil)
        # Mock implementation for testing
      end

      def head(status)
        # Mock implementation
      end
    end) unless defined?(ApplicationController)
  end

  def create_test_controller(name, resource_class = nil)
    mock_request_classes
    mock_application_controller

    Class.new(ApplicationController) do
      include JPie::Controller

      define_singleton_method(:name) { name }

      if resource_class
        define_method(:resource_class) { resource_class }
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

      def head(status)
        @last_head = status
      end

      def action_name
        'show'
      end

      attr_reader :last_render, :last_head
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