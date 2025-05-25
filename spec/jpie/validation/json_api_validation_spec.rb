# frozen_string_literal: true

require 'spec_helper'
require 'rails'
require 'action_controller'

RSpec.describe JPie::Controller::JsonApiValidation do
  before do
    # Ensure ApplicationController is defined for the tests
    stub_const('ApplicationController', Class.new(ApplicationController)) unless defined?(ApplicationController)
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
      def initialize(content)
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

  let(:controller_class) do
    Class.new(ApplicationController) do
      include JPie::Controller

      def self.name
        'TestValidationController'
      end

      # Override to return a test resource class with custom validation
      def resource_class
        @resource_class ||= Class.new(JPie::Resource) do
          model User

          attributes :name, :email
          has_many :posts
          has_one :profile

          def self.supported_includes
            %w[posts profile]
          end

          def self.supported_sort_fields
            %w[name email created_at]
          end

          def self.name
            'TestUserResource'
          end
        end
      end

      attr_accessor :params, :request, :response, :last_render

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
        'test'
      end

      attr_reader :last_head
    end
  end

  let(:controller) { controller_class.new }

  describe 'JSON:API request validation' do
    context 'when validating content type' do
      it 'passes with correct content type' do
        controller.request.content_type = 'application/vnd.api+json'
        controller.request.set_method('POST')

        expect { controller.send(:validate_content_type) }.not_to raise_error
      end

      it 'raises error with incorrect content type' do
        controller.request.content_type = 'application/json'
        controller.request.set_method('POST')

        expect { controller.send(:validate_content_type) }.to raise_error(
          JPie::Errors::InvalidJsonApiRequestError,
          %r{Content-Type must be application/vnd\.api\+json}
        )
      end

      it 'skips validation for GET requests' do
        controller.request.content_type = 'application/json'
        controller.request.set_method('GET')

        expect { controller.send(:validate_content_type) }.not_to raise_error
      end
    end

    context 'when validating JSON:API structure' do
      it 'passes with valid JSON:API structure' do
        valid_json = {
          data: {
            type: 'users',
            attributes: { name: 'John' }
          }
        }.to_json

        controller.request.set_body(valid_json)
        controller.request.set_method('POST')

        expect { controller.send(:validate_json_api_structure) }.not_to raise_error
      end

      it 'raises error with missing data member' do
        invalid_json = { type: 'users' }.to_json
        controller.request.set_body(invalid_json)
        controller.request.set_method('POST')

        expect { controller.send(:validate_json_api_structure) }.to raise_error(
          JPie::Errors::InvalidJsonApiRequestError,
          /must have a top-level "data" member/
        )
      end

      it 'raises error with invalid JSON' do
        controller.request.set_body('invalid json')
        controller.request.set_method('POST')

        expect { controller.send(:validate_json_api_structure) }.to raise_error(
          JPie::Errors::InvalidJsonApiRequestError,
          /Invalid JSON/
        )
      end

      it 'raises error with missing type in resource object' do
        invalid_json = {
          data: {
            attributes: { name: 'John' }
          }
        }.to_json

        controller.request.set_body(invalid_json)
        controller.request.set_method('POST')

        expect { controller.send(:validate_json_api_structure) }.to raise_error(
          JPie::Errors::InvalidJsonApiRequestError,
          /must have a "type" member/
        )
      end

      it 'raises error with missing id for update requests' do
        invalid_json = {
          data: {
            type: 'users',
            attributes: { name: 'John' }
          }
        }.to_json

        controller.request.set_body(invalid_json)
        controller.request.set_method('PATCH')

        expect { controller.send(:validate_json_api_structure) }.to raise_error(
          JPie::Errors::InvalidJsonApiRequestError,
          /must have an "id" member for updates/
        )
      end
    end
  end

  describe 'include parameter validation' do
    it 'passes with supported includes' do
      controller.params = { include: 'posts,profile' }

      expect { controller.send(:validate_include_params) }.not_to raise_error
    end

    it 'raises error with unsupported include' do
      controller.params = { include: 'comments' }

      expect { controller.send(:validate_include_params) }.to raise_error(
        JPie::Errors::UnsupportedIncludeError,
        /Unsupported include 'comments'. Supported includes: posts, profile/
      )
    end

    it 'raises error with partially unsupported nested include' do
      controller.params = { include: 'posts.invalid' }

      expect { controller.send(:validate_include_params) }.to raise_error(
        JPie::Errors::UnsupportedIncludeError
      )
    end

    it 'passes with empty include parameter' do
      controller.params = { include: '' }

      expect { controller.send(:validate_include_params) }.not_to raise_error
    end

    it 'passes when no include parameter is present' do
      controller.params = {}

      expect { controller.send(:validate_include_params) }.not_to raise_error
    end
  end

  describe 'sort parameter validation' do
    it 'passes with supported sort fields' do
      controller.params = { sort: 'name,-email' }

      expect { controller.send(:validate_sort_params) }.not_to raise_error
    end

    it 'raises error with unsupported sort field' do
      controller.params = { sort: 'invalid_field' }

      expect { controller.send(:validate_sort_params) }.to raise_error(
        JPie::Errors::UnsupportedSortFieldError,
        /Unsupported sort field 'invalid_field'. Supported fields: name, email, created_at/
      )
    end

    it 'raises error with invalid sort field format' do
      controller.params = { sort: '123invalid' }

      expect { controller.send(:validate_sort_params) }.to raise_error(
        JPie::Errors::InvalidSortParameterError,
        /Invalid sort field format/
      )
    end

    it 'passes with descending sort syntax' do
      controller.params = { sort: '-name' }

      expect { controller.send(:validate_sort_params) }.not_to raise_error
    end

    it 'passes with empty sort parameter' do
      controller.params = { sort: '' }

      expect { controller.send(:validate_sort_params) }.not_to raise_error
    end

    it 'passes when no sort parameter is present' do
      controller.params = {}

      expect { controller.send(:validate_sort_params) }.not_to raise_error
    end
  end

  describe 'error handling integration' do
    let(:error_handling_controller) do
      controller_class.new
    end

    it 'handles InvalidJsonApiRequestError' do
      error = JPie::Errors::InvalidJsonApiRequestError.new(detail: 'Test error')
      error_handling_controller.send(:handle_invalid_json_api_request, error)

      expect(error_handling_controller.last_render[:json]).to have_key(:errors)
      expect(error_handling_controller.last_render[:status]).to eq(400)
    end

    it 'handles UnsupportedIncludeError' do
      error = JPie::Errors::UnsupportedIncludeError.new(
        include_path: 'invalid',
        supported_includes: ['valid']
      )
      error_handling_controller.send(:handle_unsupported_include, error)

      expect(error_handling_controller.last_render[:json]).to have_key(:errors)
      expect(error_handling_controller.last_render[:status]).to eq(400)
    end

    it 'handles UnsupportedSortFieldError' do
      error = JPie::Errors::UnsupportedSortFieldError.new(
        sort_field: 'invalid',
        supported_fields: ['valid']
      )
      error_handling_controller.send(:handle_unsupported_sort_field, error)

      expect(error_handling_controller.last_render[:json]).to have_key(:errors)
      expect(error_handling_controller.last_render[:status]).to eq(400)
    end
  end
end
