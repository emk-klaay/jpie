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
  end

  describe '.type' do
    it 'returns the inferred type name' do
      expect(test_resource_class.type).to eq('users')
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

  describe 'method delegation' do
    it 'delegates unknown methods to the wrapped object' do
      # Add a method to the model instance
      def model_instance.custom_method
        'custom_result'
      end

      expect(resource_instance.custom_method).to eq('custom_result')
    end
  end
end
