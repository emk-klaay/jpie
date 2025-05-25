# frozen_string_literal: true

require 'spec_helper'
require 'rails'
require 'action_controller'

RSpec.describe JPie::Controller::JsonApiValidation do
  let(:test_resource_class) do
    Class.new(JPie::Resource) do
      model User

      attributes :name, :email
      has_many :posts

      def self.supported_includes
        %w[posts]
      end

      def self.supported_sort_fields
        %w[name email created_at]
      end

      def self.name
        'TestUserResource'
      end
    end
  end

  let(:controller_class) { create_test_controller('TestValidationController', test_resource_class) }
  let(:controller) { controller_class.new }

  describe 'JSON:API request validation' do
    context 'when validating content type' do
      include_examples 'JSON:API content type validation'
    end

    context 'when validating JSON:API structure' do
      include_examples 'JSON:API structure validation'
    end

    context 'when validating resource type through create action' do
      it 'passes with correct resource type' do
        valid_json = {
          data: {
            type: 'users',
            attributes: { name: 'John' }
          }
        }.to_json

        controller.request.body = valid_json
        controller.request.method = 'POST'
        controller.request.content_type = 'application/vnd.api+json'

        expect { controller.create }.not_to raise_error
      end

      it 'raises error with incorrect resource type' do
        invalid_json = {
          data: {
            type: 'wrong_type',
            attributes: { name: 'John' }
          }
        }.to_json

        controller.request.body = invalid_json
        controller.request.method = 'POST'
        controller.request.content_type = 'application/vnd.api+json'

        expect { controller.create }.to raise_error(JPie::Errors::BadRequestError)
      end
    end

    context 'when validating attributes through create action' do
      it 'passes with valid attributes' do
        valid_json = {
          data: {
            type: 'users',
            attributes: { name: 'John', email: 'john@example.com' }
          }
        }.to_json

        controller.request.body = valid_json
        controller.request.method = 'POST'
        controller.request.content_type = 'application/vnd.api+json'

        expect { controller.create }.not_to raise_error
      end

      it 'raises error with invalid attributes' do
        invalid_json = {
          data: {
            type: 'users',
            attributes: { invalid_field: 'value' }
          }
        }.to_json

        controller.request.body = invalid_json
        controller.request.method = 'POST'
        controller.request.content_type = 'application/vnd.api+json'

        expect { controller.create }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe 'include parameter validation' do
    let(:user) { User.create!(name: 'Test User', email: 'test@example.com') }

    it 'passes with valid include parameters' do
      controller.params = { id: user.id.to_s, include: 'posts' }

      expect { controller.show }.not_to raise_error
    end

    it 'raises error with invalid include parameters' do
      controller.params = { id: user.id.to_s, include: 'invalid_relationship' }

      expect { controller.show }.to raise_error(JPie::Errors::UnsupportedIncludeError)
    end

    it 'handles empty include parameters' do
      controller.params = { id: user.id.to_s, include: '' }

      expect { controller.show }.not_to raise_error
    end

    it 'raises error with unsupported nested includes' do
      controller.params = { id: user.id.to_s, include: 'posts.invalid_nested' }

      expect { controller.show }.to raise_error(JPie::Errors::UnsupportedIncludeError)
    end
  end

  describe 'sort parameter validation' do
    it 'passes with valid sort parameters' do
      controller.params = { sort: 'name,email' }

      expect { controller.index }.not_to raise_error
    end

    it 'passes with descending sort parameters' do
      controller.params = { sort: '-name,email' }

      expect { controller.index }.not_to raise_error
    end

    it 'raises error with invalid sort parameters' do
      controller.params = { sort: 'invalid_field' }

      expect { controller.index }.to raise_error(JPie::Errors::UnsupportedSortFieldError)
    end

    it 'handles empty sort parameter' do
      controller.params = { sort: '' }

      expect { controller.index }.not_to raise_error
    end
  end

  describe 'pagination parameter validation' do
    it 'handles pagination parameters without error' do
      controller.params = { page: { number: '1', size: '10' } }

      expect { controller.index }.not_to raise_error
    end
  end

  describe 'filter parameter validation' do
    it 'handles filter parameters without error' do
      controller.params = { filter: { name: 'John' } }

      expect { controller.index }.not_to raise_error
    end
  end

  describe 'parameter validation integration' do
    it 'validates multiple parameters together' do
      controller.params = { sort: 'name', include: 'posts' }

      expect { controller.index }.not_to raise_error
    end

    it 'handles complex parameter combinations' do
      controller.params = {
        sort: '-name,email',
        include: 'posts'
      }

      expect { controller.index }.not_to raise_error
    end
  end
end
