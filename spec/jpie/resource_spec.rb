# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JPie::Resource do
  let(:model_instance) do
    User.create!(
      name: 'John Doe',
      email: 'john@example.com'
    )
  end

  let(:resource_instance) { UserResource.new(model_instance) }

  describe '.model' do
    it 'returns the configured model class' do
      expect(UserResource.model).to eq(User)
    end

    it 'infers model class from resource name when not explicitly set' do
      class InferenceTestResource < JPie::Resource
        # No explicit model set
      end

      # The implementation will try to constantize 'InferenceTest' from 'InferenceTestResource'
      # Since no InferenceTest class exists, this should return nil
      expect(InferenceTestResource.model).to be_nil
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
      expect(UserResource.type).to eq('users')
    end

    it 'falls back to class name when model unavailable' do
      class StandaloneResource < JPie::Resource
        # No model set
      end

      expect(StandaloneResource.type).to eq('standalones')
    end
  end

  describe '.attribute' do
    it 'defines attribute methods', :aggregate_failures do
      expect(resource_instance).to respond_to(:name)
      expect(resource_instance).to respond_to(:email)
    end

    it 'adds attributes to the _attributes list' do
      expect(UserResource._attributes).to contain_exactly(:name, :email, :created_at, :updated_at)
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
    it 'returns a hash of all attributes', :aggregate_failures do
      attributes = resource_instance.attributes_hash

      expect(attributes).to include(
        name: 'John Doe',
        email: 'john@example.com'
      )
      expect(attributes).to have_key(:created_at)
      expect(attributes).to have_key(:updated_at)
    end
  end

  describe 'attribute access' do
    it 'returns the correct attribute values', :aggregate_failures do
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
    it 'properly inherits attributes from parent class', :aggregate_failures do
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
