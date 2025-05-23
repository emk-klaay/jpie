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
    it 'automatically infers User model from UserResource' do
      expect(UserResource.model).to eq(User)
    end

    it 'automatically infers Post model from PostResource' do
      expect(PostResource.model).to eq(Post)
    end

    it 'allows explicit model override when specified' do
      class ExplicitModelResource < JPie::Resource
        model User # Explicitly set to User
      end

      expect(ExplicitModelResource.model).to eq(User)
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
      expect(UserResource._attributes).to contain_exactly(:name, :email)
    end
  end

  describe '.meta_attribute' do
    it 'defines meta attribute methods', :aggregate_failures do
      expect(resource_instance).to respond_to(:created_at)
      expect(resource_instance).to respond_to(:updated_at)
    end

    it 'adds meta attributes to the _meta_attributes list' do
      expect(UserResource._meta_attributes).to contain_exactly(:created_at, :updated_at)
    end
  end

  describe '.relationship' do
    it 'defines relationship methods and adds to _relationships hash' do
      test_resource_class = Class.new(JPie::Resource) do
        relationship :test_rel, resource: 'TestResource'
      end

      expect(test_resource_class._relationships[:test_rel]).to include(resource: 'TestResource')
    end
  end

  describe '.has_many' do
    it 'infers resource class name from relationship name' do
      test_resource_class = Class.new(JPie::Resource) do
        has_many :posts
      end

      expect(test_resource_class._relationships[:posts]).to include(resource: 'PostResource')
    end

    it 'allows explicit resource class override' do
      test_resource_class = Class.new(JPie::Resource) do
        has_many :custom_posts, resource: 'ArticleResource'
      end

      expect(test_resource_class._relationships[:custom_posts]).to include(resource: 'ArticleResource')
    end

    it 'handles pluralized relationship names correctly' do
      test_resource_class = Class.new(JPie::Resource) do
        has_many :categories
      end

      expect(test_resource_class._relationships[:categories]).to include(resource: 'CategoryResource')
    end

    it 'defines the relationship method on the resource instance' do
      test_resource_class = Class.new(JPie::Resource) do
        has_many :posts
      end

      instance = test_resource_class.new(double('model'))
      expect(instance).to respond_to(:posts)
    end
  end

  describe '.has_one' do
    it 'infers resource class name from relationship name' do
      test_resource_class = Class.new(JPie::Resource) do
        has_one :user
      end

      expect(test_resource_class._relationships[:user]).to include(resource: 'UserResource')
    end

    it 'allows explicit resource class override' do
      test_resource_class = Class.new(JPie::Resource) do
        has_one :author, resource: 'UserResource'
      end

      expect(test_resource_class._relationships[:author]).to include(resource: 'UserResource')
    end

    it 'handles singularized relationship names correctly' do
      test_resource_class = Class.new(JPie::Resource) do
        has_one :organization
      end

      expect(test_resource_class._relationships[:organization]).to include(resource: 'OrganizationResource')
    end

    it 'defines the relationship method on the resource instance' do
      test_resource_class = Class.new(JPie::Resource) do
        has_one :user
      end

      instance = test_resource_class.new(double('model'))
      expect(instance).to respond_to(:user)
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
      expect(attributes).not_to have_key(:created_at)
      expect(attributes).not_to have_key(:updated_at)
    end
  end

  describe '#meta_hash' do
    it 'returns a hash of all meta attributes', :aggregate_failures do
      meta = resource_instance.meta_hash

      expect(meta).to have_key(:created_at)
      expect(meta).to have_key(:updated_at)
      expect(meta[:created_at]).to be_a(Time)
      expect(meta[:updated_at]).to be_a(Time)
    end
  end

  describe 'attribute access' do
    it 'returns the correct attribute values', :aggregate_failures do
      expect(resource_instance.name).to eq('John Doe')
      expect(resource_instance.email).to eq('john@example.com')
    end
  end

  describe 'meta attribute access' do
    it 'returns the correct meta attribute values', :aggregate_failures do
      expect(resource_instance.created_at).to be_a(Time)
      expect(resource_instance.updated_at).to be_a(Time)
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
        meta_attributes :created_at
      end

      class DerivedResource < BaseResource
        attributes :email
        meta_attributes :updated_at
      end

      expect(DerivedResource._attributes).to include(:name, :email)
      expect(DerivedResource._meta_attributes).to include(:created_at, :updated_at)
      expect(BaseResource._attributes).to eq([:name])
      expect(BaseResource._meta_attributes).to eq([:created_at])
    end

    it 'properly inherits relationships from parent class', :aggregate_failures do
      class BaseResourceWithRel < JPie::Resource
        has_many :posts
      end

      class DerivedResourceWithRel < BaseResourceWithRel
        has_one :user
      end

      expect(DerivedResourceWithRel._relationships).to include(:posts, :user)
      expect(DerivedResourceWithRel._relationships[:posts][:resource]).to eq('PostResource')
      expect(DerivedResourceWithRel._relationships[:user][:resource]).to eq('UserResource')
      expect(BaseResourceWithRel._relationships).to include(:posts)
      expect(BaseResourceWithRel._relationships).not_to include(:user)
    end
  end

  describe '.scope' do
    it 'returns all records by default' do
      allow(User).to receive(:all).and_return('all_users')
      expect(UserResource.scope).to eq('all_users')
    end

    it 'accepts a context parameter without error' do
      context = { current_user: double('user') }
      allow(User).to receive(:all).and_return('all_users')
      expect(UserResource.scope(context)).to eq('all_users')
    end

    it 'can be overridden for authorization' do
      test_resource_class = Class.new(JPie::Resource) do
        model User

        def self.scope(context = {})
          current_user = context[:current_user]
          return model.none unless current_user&.admin?

          model.all
        end
      end

      # Test with no user
      expect(test_resource_class.scope).to eq(User.none)

      # Test with non-admin user
      user = double('user', admin?: false)
      context = { current_user: user }
      expect(test_resource_class.scope(context)).to eq(User.none)

      # Test with admin user
      admin_user = double('admin_user', admin?: true)
      admin_context = { current_user: admin_user }
      allow(User).to receive(:all).and_return('admin_access')
      expect(test_resource_class.scope(admin_context)).to eq('admin_access')
    end
  end
end
