# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JPie::Resource do
  # Test resource using the ActiveRecord User model from database.rb
  let(:test_resource_class) do
    Class.new(JPie::Resource) do
      model User
      attributes :name, :email
    end
  end

  let(:model_instance) do
    User.create!(
      name: 'John Doe',
      email: 'john@example.com'
    )
  end

  let(:resource_instance) { test_resource_class.new(model_instance) }

  describe '.model' do
    it 'returns the configured model class' do
      expect(test_resource_class.model).to eq(User)
    end

    it 'infers model class from resource name when not explicitly set' do
      class TestResource < JPie::Resource
        # No explicit model set
      end

      # The implementation will try to constantize 'Test' from 'TestResource'
      # Since TestModel exists (defined in database.rb), it should be found
      expect(TestResource.model).to eq(TestModel)
    end

    it 'falls back to nil when model cannot be inferred' do
      class UnknownResource < JPie::Resource
        # No explicit model set, and 'Unknown' class doesn't exist
      end

      expect(UnknownResource.model).to be_nil
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
    end

    it 'adds attributes to the _attributes list' do
      expect(test_resource_class._attributes).to contain_exactly(:name, :email)
    end
  end

  describe '#id' do
    it 'returns the object id' do
      expect(resource_instance.id).to eq(model_instance.id)
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
                                 email: 'john@example.com'
                               })
    end
  end

  describe 'attribute access' do
    it 'returns the correct attribute values' do
      expect(resource_instance.name).to eq('John Doe')
      expect(resource_instance.email).to eq('john@example.com')
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
