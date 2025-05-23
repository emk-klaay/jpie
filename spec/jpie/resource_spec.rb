# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JPie::Resource do
  # Mock model for testing
  let(:mock_model) do
    Class.new do
      attr_accessor :id, :name, :email, :created_at

      def initialize(attributes = {})
        attributes.each { |key, value| public_send("#{key}=", value) }
      end

      def self.model_name
        OpenStruct.new(plural: 'users')
      end
    end
  end

  let(:test_resource_class) do
    model_class = mock_model
    Class.new(described_class) do
      model model_class
      attributes :name, :email
      attribute :created_at
    end
  end

  let(:model_instance) do
    mock_model.new(
      id: 1,
      name: 'John Doe',
      email: 'john@example.com',
      created_at: Time.parse('2024-01-01T12:00:00Z')
    )
  end

  let(:resource_instance) { test_resource_class.new(model_instance) }

  describe '.model' do
    it 'sets and gets the model class' do
      expect(test_resource_class.model).to eq(mock_model)
    end

    it 'infers model class from resource name when not explicitly set' do
      class TestResource < JPie::Resource
        # No explicit model set
      end

      # The implementation will try to constantize 'Test' from 'TestResource'
      # Since TestModel exists (defined in controller_spec.rb), it should be found
      expect(TestResource.model).to eq(TestModel)
    end

    it 'returns nil when model cannot be inferred' do
      class UnknownResource < JPie::Resource
        # No explicit model set and can't be inferred
      end

      expect(UnknownResource.send(:infer_model_class)).to be_nil
    end
  end

  describe '.type' do
    it 'returns custom type when set' do
      class CustomResource < JPie::Resource
        type 'custom_things'
      end

      expect(CustomResource.type).to eq('custom_things')
    end

    it 'returns the inferred type name' do
      expect(test_resource_class.type).to eq('users')
    end

    it 'falls back to class name when model unavailable' do
      class StandaloneResource < JPie::Resource
        # No model set
      end

      expect(StandaloneResource.type).to eq('standalones')
    end
  end

  describe '.attribute' do
    it 'defines attribute methods' do
      expect(resource_instance).to respond_to(:name)
      expect(resource_instance).to respond_to(:email)
      expect(resource_instance).to respond_to(:created_at)
    end

    it 'adds attributes to the _attributes list' do
      expect(test_resource_class._attributes).to contain_exactly(:name, :email, :created_at)
    end
  end

  describe '#id' do
    it 'returns the object id' do
      expect(resource_instance.id).to eq(1)
    end
  end

  describe '#type' do
    it 'returns the class type' do
      expect(resource_instance.type).to eq('users')
    end
  end

  describe '#attributes_hash' do
    it 'returns a hash of all attributes' do
      attributes = resource_instance.attributes_hash

      expect(attributes).to eq({
                                 name: 'John Doe',
                                 email: 'john@example.com',
                                 created_at: Time.parse('2024-01-01T12:00:00Z')
                               })
    end
  end

  describe 'attribute access' do
    it 'returns the correct attribute values' do
      expect(resource_instance.name).to eq('John Doe')
      expect(resource_instance.email).to eq('john@example.com')
      expect(resource_instance.created_at).to eq(Time.parse('2024-01-01T12:00:00Z'))
    end
  end

  describe 'method_missing and respond_to_missing?' do
    it 'delegates unknown methods to the object' do
      # Define a custom method on the model instance
      def model_instance.custom_method
        'custom_result'
      end
      
      expect(resource_instance.custom_method).to eq('custom_result')
    end

    it 'responds to methods that the object responds to' do
      allow(model_instance).to receive(:respond_to?).with(:custom_method, false).and_return(true)
      expect(resource_instance.respond_to?(:custom_method)).to be true
    end

    it 'raises NoMethodError for methods object does not respond to' do
      expect { resource_instance.non_existent_method }.to raise_error(NoMethodError)
    end
  end

  describe 'inheritance' do
    it 'properly inherits attributes from parent class' do
      class BaseResource < JPie::Resource
        attributes :name
      end

      class DerivedResource < BaseResource
        attributes :email
      end

      expect(DerivedResource._attributes).to include(:name, :email)
      expect(BaseResource._attributes).to eq([:name])
    end
  end
end
