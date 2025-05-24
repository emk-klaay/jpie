# frozen_string_literal: true

require 'spec_helper'
require 'rails'
require 'action_controller'
require 'active_record'

# Mock controller for testing
class ApplicationController < ActionController::Base; end

# Test controller that should automatically infer UserResource from its name
class UsersController < ApplicationController
  include JPie::Controller

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

RSpec.describe JPie::Controller do
  let(:controller) { UsersController.new }
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

  describe 'CRUD methods' do
    it 'defines all CRUD methods', :aggregate_failures do
      expect(controller).to respond_to(:index)
      expect(controller).to respond_to(:show)
      expect(controller).to respond_to(:create)
      expect(controller).to respond_to(:update)
      expect(controller).to respond_to(:destroy)
    end
  end

  describe '#index' do
    it 'renders all resources' do
      controller.index

      expect(controller.last_render[:json]).to have_key(:data)
    end

    it 'returns array data for index' do
      controller.index

      expect(controller.last_render[:json][:data]).to be_an(Array)
    end

    it 'returns ok status for index' do
      controller.index

      expect(controller.last_render[:status]).to eq(:ok)
    end

    context 'with sorting' do
      it 'applies sorting when sort parameter is provided' do
        controller.params = { sort: 'name' }

        # Mock the resource class to verify sort is called
        allow(UserResource).to receive_messages(scope: User.all, sort: User.all)

        controller.index

        expect(UserResource).to have_received(:sort).with(User.all, ['name'])
      end

      it 'applies multiple sort fields' do
        controller.params = { sort: 'name,-email' }

        allow(UserResource).to receive_messages(scope: User.all, sort: User.all)

        controller.index

        expect(UserResource).to have_received(:sort).with(User.all, ['name', '-email'])
      end

      it 'does not apply sorting when no sort parameter' do
        controller.params = {}

        allow(UserResource).to receive_messages(scope: User.all, sort: User.all)

        controller.index

        expect(UserResource).not_to have_received(:sort)
      end

      it 'handles empty sort parameter' do
        controller.params = { sort: '' }

        allow(UserResource).to receive_messages(scope: User.all, sort: User.all)

        controller.index

        expect(UserResource).not_to have_received(:sort)
      end
    end
  end

  describe '#show' do
    it 'renders a single resource' do
      controller.params = { id: test_record.id.to_s }
      controller.show

      expect(controller.last_render[:json]).to have_key(:data)
    end

    it 'returns hash data for show' do
      controller.params = { id: test_record.id.to_s }
      controller.show

      expect(controller.last_render[:json][:data]).to be_a(Hash)
    end

    it 'returns ok status for show' do
      controller.params = { id: test_record.id.to_s }
      controller.show

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
        # Define a controller class for error testing
        Class.new(ApplicationController) do
          include JPie::Controller

          # Override the inferred resource with UserResource for testing
          def self.name
            'UsersController'
          end

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

      it 'handles ActiveRecord::RecordNotFound with errors key' do
        controller_with_errors.send(:render_not_found_error, ActiveRecord::RecordNotFound.new('Not found'))

        expect(controller_with_errors.last_render[:json]).to have_key(:errors)
      end

      it 'handles ActiveRecord::RecordNotFound with 404 status' do
        controller_with_errors.send(:render_not_found_error, ActiveRecord::RecordNotFound.new('Not found'))

        expect(controller_with_errors.last_render[:status]).to eq(404)
      end

      it 'handles ActiveRecord::RecordInvalid with errors key' do
        invalid_error = ActiveRecord::RecordInvalid.new
        controller_with_errors.send(:render_validation_error, invalid_error)

        expect(controller_with_errors.last_render[:json]).to have_key(:errors)
      end

      it 'handles ActiveRecord::RecordInvalid with unprocessable_entity status' do
        invalid_error = ActiveRecord::RecordInvalid.new
        controller_with_errors.send(:render_validation_error, invalid_error)

        expect(controller_with_errors.last_render[:status]).to eq(:unprocessable_entity)
      end

      it 'handles JPie::Errors::Error with errors key' do
        jpie_error = JPie::Errors::BadRequestError.new(detail: 'Bad request')
        controller_with_errors.send(:render_jsonapi_error, jpie_error)

        expect(controller_with_errors.last_render[:json]).to have_key(:errors)
      end

      it 'handles JPie::Errors::Error with correct status' do
        jpie_error = JPie::Errors::BadRequestError.new(detail: 'Bad request')
        controller_with_errors.send(:render_jsonapi_error, jpie_error)

        expect(controller_with_errors.last_render[:status]).to eq(400)
      end
    end
  end

  describe 'context building' do
    it 'builds context with controller' do
      context = controller.send(:context)
      expect(context[:controller]).to eq(controller)
    end

    it 'builds context with action' do
      context = controller.send(:context)
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
      controller.send(:render_jsonapi, User.new, meta: { total: 1 })

      expect(controller.last_render[:json]).to have_key(:meta)
    end

    it 'includes correct meta data in single resource response' do
      controller.send(:render_jsonapi, User.new, meta: { total: 1 })

      expect(controller.last_render[:json][:meta]).to eq({ total: 1 })
    end

    it 'includes meta in collection response' do
      controller.send(:render_jsonapi, [User.new], meta: { total: 1 })

      expect(controller.last_render[:json]).to have_key(:meta)
    end

    it 'includes correct meta data in collection response' do
      controller.send(:render_jsonapi, [User.new], meta: { total: 1 })

      expect(controller.last_render[:json][:meta]).to eq({ total: 1 })
    end
  end

  describe 'resource inference' do
    it 'automatically infers UserResource from UsersController' do
      expect(controller.resource_class).to eq(UserResource)
    end

    it 'allows explicit resource setting with jsonapi_resource macro' do
      # Test that explicit setting still works
      explicit_controller_class = Class.new(ApplicationController) do
        include JPie::Controller
        jsonapi_resource PostResource

        def self.name
          'SomeOtherController'
        end
      end

      explicit_controller = explicit_controller_class.new
      expect(explicit_controller.resource_class).to eq(PostResource)
    end

    it 'handles controllers that do not match any resource' do
      unknown_controller_class = Class.new(ApplicationController) do
        include JPie::Controller

        def self.name
          'UnknownThingsController'
        end
      end

      # Should not raise an error, just won't have resource methods
      expect { unknown_controller_class.new }.not_to raise_error
    end
  end

  describe 'resource scoping' do
    let(:scoped_controller_class) do
      Class.new(ApplicationController) do
        include JPie::Controller

        def self.name
          'ScopedUsersController'
        end

        # Override to return a test resource class with custom scoping
        def resource_class
          @resource_class ||= Class.new(JPie::Resource) do
            model User

            def self.scope(context = {})
              current_user = context[:current_user]
              if current_user&.admin?
                model.all
              else
                model.where(active: true)
              end
            end

            def self.name
              'ScopedUserResource'
            end
          end
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

    let(:scoped_controller) { scoped_controller_class.new }

    it 'uses resource scope for index action' do
      # Mock the scoped query
      scoped_relation = double('scoped_relation')
      expected_context = { current_user: nil, controller: scoped_controller, action: 'test' }
      expect(scoped_controller.resource_class).to receive(:scope).with(expected_context).and_return(scoped_relation)
      expect(scoped_controller).to receive(:render_jsonapi).with(scoped_relation)

      scoped_controller.index
    end

    it 'uses resource scope for show action' do
      scoped_controller.params[:id] = '123'
      scoped_relation = double('scoped_relation')
      record = double('record')
      expected_context = { current_user: nil, controller: scoped_controller, action: 'test' }

      expect(scoped_controller.resource_class).to receive(:scope).with(expected_context).and_return(scoped_relation)
      expect(scoped_relation).to receive(:find).with('123').and_return(record)
      expect(scoped_controller).to receive(:render_jsonapi).with(record)

      scoped_controller.show
    end

    it 'uses resource scope for update action' do
      scoped_controller.params[:id] = '123'
      scoped_relation = double('scoped_relation')
      record = double('record')
      expected_context = { current_user: nil, controller: scoped_controller, action: 'test' }

      expect(scoped_controller.resource_class).to receive(:scope).with(expected_context).and_return(scoped_relation)
      expect(scoped_relation).to receive(:find).with('123').and_return(record)
      expect(scoped_controller).to receive(:deserialize_params).and_return({})
      expect(record).to receive(:update!).with({})
      expect(scoped_controller).to receive(:render_jsonapi).with(record)

      scoped_controller.update
    end

    it 'uses resource scope for destroy action' do
      scoped_controller.params[:id] = '123'
      scoped_relation = double('scoped_relation')
      record = double('record')
      expected_context = { current_user: nil, controller: scoped_controller, action: 'test' }

      expect(scoped_controller.resource_class).to receive(:scope).with(expected_context).and_return(scoped_relation)
      expect(scoped_relation).to receive(:find).with('123').and_return(record)
      expect(record).to receive(:destroy!)
      expect(scoped_controller).to receive(:head).with(:no_content)

      scoped_controller.destroy
    end
  end
end
