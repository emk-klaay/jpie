# frozen_string_literal: true

require 'spec_helper'
require 'rails'
require 'action_controller'
require 'active_record'

# Mock Rails environment
class ApplicationController < ActionController::Base; end

# Mock model for testing
class TestModel
  attr_accessor :id, :name, :email

  def self.all
    [new(id: 1, name: 'John', email: 'john@example.com')]
  end

  def self.find(id)
    new(id: id, name: 'John', email: 'john@example.com')
  end

  def self.create!(attributes)
    instance = new
    attributes.each { |key, value| instance.send("#{key}=", value) }
    instance.id = 1
    instance
  end

  def self.model_name
    OpenStruct.new(plural: 'test_models')
  end

  def update!(attributes)
    attributes.each { |key, value| send("#{key}=", value) }
    self
  end

  def destroy!
    true
  end

  def initialize(attributes = {})
    attributes.each { |key, value| send("#{key}=", value) }
  end
end

# Mock resource for testing
class TestResource < JPie::Resource
  model TestModel
  attributes :name, :email
end

RSpec.describe JPie::Controller do
  let(:controller_class) do
    Class.new(ApplicationController) do
      include JPie::Controller
      jsonapi_resource TestResource

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
      controller.params = { id: '1' }
      controller.show
      
      expect(controller.last_render[:json]).to have_key(:data)
      expect(controller.last_render[:json][:data]).to be_a(Hash)
      expect(controller.last_render[:status]).to eq(:ok)
    end
  end

  describe '#destroy' do
    it 'returns no content status' do
      controller.params = { id: '1' }
      controller.destroy
      
      expect(controller.last_head).to eq(:no_content)
    end
  end

  describe '#model_class' do
    it 'returns the resource model class' do
      expect(controller.send(:model_class)).to eq(TestModel)
    end
  end
end 