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
  let(:controller_class) { create_test_controller('UsersController') }
  let(:controller) { controller_class.new }
  let(:test_record) { User.create!(name: 'John', email: 'john@example.com') }

  before do
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

    context 'with sorting' do
      it 'applies sorting when sort parameter is provided' do
        controller.params = { sort: 'name' }
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

      expect_json_api_response(controller)
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
      let(:error_controller_class) do
        create_test_controller('UsersController').tap do |klass|
          klass.class_eval do
            def test_not_found
              raise ActiveRecord::RecordNotFound, 'Record not found'
            end

            def test_invalid_record
              raise ActiveRecord::RecordInvalid.new
            end
          end
        end
      end

      let(:error_controller) { error_controller_class.new }

      it 'handles RecordNotFound with 404 status' do
        expect { error_controller.test_not_found }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'handles RecordInvalid with validation errors' do
        expect { error_controller.test_invalid_record }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe 'resource class inference' do
    context 'with standard controller name' do
      let(:posts_controller) { create_test_controller('PostsController').new }

      it 'infers PostResource from PostsController' do
        expect(posts_controller.send(:resource_class)).to eq(PostResource)
      end
    end

    context 'with non-standard controller name' do
      let(:custom_controller) { create_test_controller('SomeOtherController').new }

      it 'raises error for unknown resource' do
        expect { custom_controller.send(:resource_class) }.to raise_error(NameError)
      end
    end

    context 'with scoped controller' do
      let(:scoped_resource_class) do
        Class.new(JPie::Resource) do
          model User

          def self.scope(context = {})
            current_user = context[:current_user]
            return User.none unless current_user

            User.where(id: current_user.id)
          end

          def self.name
            'ScopedUserResource'
          end
        end
      end

      let(:scoped_controller_class) do
        resource_class = scoped_resource_class
        create_test_controller('ScopedUsersController').tap do |klass|
          klass.class_eval do
            define_method(:resource_class) { resource_class }
          end
        end
      end

      let(:scoped_controller) { scoped_controller_class.new }

      it 'uses custom resource class when overridden' do
        expect(scoped_controller.send(:resource_class)).to eq(scoped_resource_class)
      end

      it 'applies scoping in index action' do
        user = User.create!(name: 'Scoped User', email: 'scoped@example.com')
        
        # Add current_user method to the controller
        scoped_controller.define_singleton_method(:current_user) { user }

        scoped_controller.index

        expect_json_api_response(scoped_controller)
      end
    end
  end
end
