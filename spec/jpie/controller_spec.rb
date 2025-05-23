# frozen_string_literal: true

require 'spec_helper'
require 'rails'
require 'action_controller'
require 'active_record'

# Mock controller for testing
class ApplicationController < ActionController::Base; end

RSpec.describe JPie::Controller do
  let(:controller_class) do
    Class.new(ApplicationController) do
      include JPie::Controller
      jsonapi_resource UserResource

      # Mock Rails controller methods
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
        'test'
      end

      attr_reader :last_render, :last_head
    end
  end

  let(:controller) { controller_class.new }
  let(:test_record) { User.create!(name: 'John', email: 'john@example.com') }

  before do
    # Define mock classes
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

    # Ensure test record is created
    test_record
  end

  describe 'automatic CRUD methods' do
    it 'defines index method' do
      expect(controller).to respond_to(:index)
    end

    it 'defines show method' do
      expect(controller).to respond_to(:show)
    end

    it 'defines create method' do
      expect(controller).to respond_to(:create)
    end

    it 'defines update method' do
      expect(controller).to respond_to(:update)
    end

    it 'defines destroy method' do
      expect(controller).to respond_to(:destroy)
    end
  end

  describe '#index' do
    it 'renders all resources' do
      controller.index

      expect(controller.last_render[:json]).to have_key(:data)
      expect(controller.last_render[:json][:data]).to be_an(Array)
      expect(controller.last_render[:status]).to eq(:ok)
    end
  end

  describe '#show' do
    it 'renders a single resource' do
      controller.params = { id: test_record.id.to_s }
      controller.show

      expect(controller.last_render[:json]).to have_key(:data)
      expect(controller.last_render[:json][:data]).to be_a(Hash)
      expect(controller.last_render[:status]).to eq(:ok)
    end
  end

  describe '#destroy' do
    it 'returns no content status' do
      controller.params = { id: test_record.id.to_s }
      controller.destroy

      expect(controller.last_head).to eq(:no_content)
    end
  end

  describe '#model_class' do
    it 'returns the resource model class' do
      expect(controller.send(:model_class)).to eq(User)
    end
  end

  describe 'error handling' do
    before do
      # Mock ActiveRecord errors for testing
      stub_const('ActiveRecord::RecordNotFound', Class.new(StandardError))
      stub_const('ActiveRecord::RecordInvalid', Class.new(StandardError) do
        attr_reader :record

        def initialize(record = nil)
          mock_record = OpenStruct.new(errors: OpenStruct.new(full_messages: ['Test error']))
          @record = record || mock_record
          super('Invalid record')
        end
      end)
    end

    describe 'rescue_from handlers' do
      let(:controller_with_errors) do
        Class.new(ApplicationController) do
          include JPie::Controller
          jsonapi_resource UserResource

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
        end.new
      end

      it 'handles ActiveRecord::RecordNotFound' do
        controller_with_errors.send(:render_not_found_error, ActiveRecord::RecordNotFound.new('Not found'))

        expect(controller_with_errors.last_render[:json]).to have_key(:errors)
        expect(controller_with_errors.last_render[:status]).to eq(404)
      end

      it 'handles ActiveRecord::RecordInvalid' do
        invalid_error = ActiveRecord::RecordInvalid.new
        controller_with_errors.send(:render_validation_error, invalid_error)

        expect(controller_with_errors.last_render[:json]).to have_key(:errors)
        expect(controller_with_errors.last_render[:status]).to eq(:unprocessable_entity)
      end

      it 'handles JPie::Errors::Error' do
        jpie_error = JPie::Errors::BadRequestError.new(detail: 'Bad request')
        controller_with_errors.send(:render_jsonapi_error, jpie_error)

        expect(controller_with_errors.last_render[:json]).to have_key(:errors)
        expect(controller_with_errors.last_render[:status]).to eq(400)
      end
    end
  end

  describe 'context building' do
    it 'builds context with controller and action' do
      context = controller.send(:context)
      expect(context[:controller]).to eq(controller)
      expect(context[:action]).to eq('test')
    end

    it 'includes current_user when available' do
      allow(controller).to receive(:try).with(:current_user).and_return('user')
      context = controller.send(:context)
      expect(context[:current_user]).to eq('user')
    end
  end

  describe 'parameter deserialization' do
    it 'deserializes valid JSON' do
      mock_body = double('body')
      allow(mock_body).to receive(:read).and_return('{"data": {"type": "users", "attributes": {"name": "test"}}}')

      mock_request = double('request', body: mock_body)
      controller.request = mock_request

      result = controller.send(:deserialize_params)
      expect(result).to have_key('name')
    end

    it 'raises error for invalid JSON' do
      mock_body = double('body')
      allow(mock_body).to receive(:read).and_return('invalid json')

      mock_request = double('request', body: mock_body)
      controller.request = mock_request

      expect { controller.send(:deserialize_params) }.to raise_error(JPie::Errors::BadRequestError)
    end
  end

  describe 'rendering with meta' do
    it 'includes meta in single resource response' do
      controller.send(:render_jsonapi_resource, User.new, meta: { total: 1 })

      expect(controller.last_render[:json]).to have_key(:meta)
      expect(controller.last_render[:json][:meta]).to eq({ total: 1 })
    end

    it 'includes meta in collection response' do
      controller.send(:render_jsonapi_resources, [User.new], meta: { total: 1 })

      expect(controller.last_render[:json]).to have_key(:meta)
      expect(controller.last_render[:json][:meta]).to eq({ total: 1 })
    end
  end
end
