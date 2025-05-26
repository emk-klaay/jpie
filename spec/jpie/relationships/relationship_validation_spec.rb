# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JPie::Controller::RelationshipValidation do
  let(:controller_class) { create_test_controller('TestController', PostResource) }
  let(:controller) { controller_class.new }
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let(:post) { Post.create!(title: 'Test Post', content: 'Content', user:) }
  let(:tag) { Tag.create!(name: 'Test Tag') }
  let(:content_type) { 'application/vnd.api+json' }
  let(:request_body) { '{}' }
  let(:params) { { id: post.id } }

  before do
    controller.params = params
    controller.request.content_type = content_type
    controller.request.body = request_body
    controller.request.method = request_method if defined?(request_method)
  end

  describe '#validate_relationship_exists' do
    context 'when relationship exists' do
      let(:params) { { id: post.id, relationship_name: 'user' } }

      it 'does not raise an error' do
        expect { controller.send(:validate_relationship_exists) }.not_to raise_error
      end
    end

    context 'when relationship does not exist' do
      let(:params) { { id: post.id, relationship_name: 'nonexistent' } }

      it 'raises NotFoundError' do
        expect { controller.send(:validate_relationship_exists) }.to raise_error(
          JPie::Errors::NotFoundError,
          "Relationship 'nonexistent' does not exist for PostResource"
        )
      end
    end

    context 'when relationship_name is not provided' do
      let(:params) { { id: post.id } }

      it 'does not raise an error' do
        expect { controller.send(:validate_relationship_exists) }.not_to raise_error
      end
    end
  end

  describe '#validate_relationship_update_request' do
    let(:request_method) { 'PATCH' }

    context 'with valid content type and body' do
      let(:params) { { id: post.id, relationship_name: 'user' } }
      let(:request_body) { '{"data": null}' }

      it 'does not raise an error' do
        expect { controller.send(:validate_relationship_update_request) }.not_to raise_error
      end
    end

    context 'with invalid content type' do
      let(:content_type) { 'application/json' }

      it 'raises InvalidJsonApiRequestError' do
        expect { controller.send(:validate_relationship_update_request) }.to raise_error(
          JPie::Errors::InvalidJsonApiRequestError,
          'Content-Type must be application/vnd.api+json for JSON:API requests'
        )
      end
    end

    context 'with missing content type' do
      let(:content_type) { nil }

      it 'raises InvalidJsonApiRequestError' do
        expect { controller.send(:validate_relationship_update_request) }.to raise_error(
          JPie::Errors::InvalidJsonApiRequestError,
          'Content-Type must be application/vnd.api+json for JSON:API requests'
        )
      end
    end

    context 'with empty request body' do
      let(:request_body) { '' }

      it 'raises BadRequestError' do
        expect { controller.send(:validate_relationship_update_request) }.to raise_error(
          JPie::Errors::BadRequestError,
          'Request body cannot be empty'
        )
      end
    end

    context 'with invalid JSON body' do
      let(:request_body) { 'invalid json' }

      it 'raises BadRequestError' do
        expect { controller.send(:validate_relationship_update_request) }.to raise_error(
          JPie::Errors::BadRequestError,
          /Invalid JSON:/
        )
      end
    end
  end

  describe '#validate_relationship_type' do
    let(:params) { { id: post.id, relationship_name: relationship_name } }
    let(:request_method) { 'PATCH' }

    context 'with to-many relationship' do
      let(:relationship_name) { 'replies' }

      context 'with valid array data' do
        let(:request_body) { '{"data": [{"type": "posts", "id": "1"}]}' }

        it 'does not raise an error' do
          expect { controller.send(:validate_relationship_type) }.not_to raise_error
        end
      end

      context 'with invalid non-array data' do
        let(:request_body) { '{"data": {"type": "posts", "id": "1"}}' }

        it 'raises BadRequestError' do
          expect { controller.send(:validate_relationship_type) }.to raise_error(
            JPie::Errors::BadRequestError,
            'The value of data must be an array for to-many relationships'
          )
        end
      end

      context 'with null data' do
        let(:request_body) { '{"data": null}' }

        it 'raises BadRequestError' do
          expect { controller.send(:validate_relationship_type) }.to raise_error(
            JPie::Errors::BadRequestError,
            'Cannot set a to-many relationship to null'
          )
        end
      end

      context 'with empty array data' do
        let(:request_body) { '{"data": []}' }

        it 'does not raise an error' do
          expect { controller.send(:validate_relationship_type) }.not_to raise_error
        end
      end
    end

    context 'with to-one relationship' do
      let(:relationship_name) { 'user' }

      context 'with valid single resource identifier' do
        let(:request_body) { '{"data": {"type": "users", "id": "1"}}' }

        it 'does not raise an error' do
          expect { controller.send(:validate_relationship_type) }.not_to raise_error
        end
      end

      context 'with invalid array data' do
        let(:request_body) { '{"data": [{"type": "users", "id": "1"}]}' }

        it 'raises BadRequestError' do
          expect { controller.send(:validate_relationship_type) }.to raise_error(
            JPie::Errors::BadRequestError,
            'The value of data must be a single resource identifier object or null for to-one relationships'
          )
        end
      end

      context 'with null data' do
        let(:request_body) { '{"data": null}' }

        it 'does not raise an error' do
          expect { controller.send(:validate_relationship_type) }.not_to raise_error
        end
      end
    end
  end

  describe '#validate_resource_identifier' do
    context 'with valid resource identifier' do
      let(:identifier) { { 'type' => 'posts', 'id' => '1' } }

      it 'does not raise an error' do
        expect { controller.send(:validate_resource_identifier, identifier) }.not_to raise_error
      end
    end

    context 'with missing type' do
      let(:identifier) { { 'id' => '1' } }

      it 'raises BadRequestError' do
        expect { controller.send(:validate_resource_identifier, identifier) }.to raise_error(
          JPie::Errors::BadRequestError,
          'Resource identifier objects must have "type" and "id" members'
        )
      end
    end

    context 'with missing id' do
      let(:identifier) { { 'type' => 'posts' } }

      it 'raises BadRequestError' do
        expect { controller.send(:validate_resource_identifier, identifier) }.to raise_error(
          JPie::Errors::BadRequestError,
          'Resource identifier objects must have "type" and "id" members'
        )
      end
    end

    context 'with non-string type' do
      let(:identifier) { { 'type' => 123, 'id' => '1' } }

      it 'raises BadRequestError' do
        expect { controller.send(:validate_resource_identifier, identifier) }.to raise_error(
          JPie::Errors::BadRequestError,
          'Resource identifier object members must be strings'
        )
      end
    end

    context 'with non-string id' do
      let(:identifier) { { 'type' => 'posts', 'id' => 123 } }

      it 'raises BadRequestError' do
        expect { controller.send(:validate_resource_identifier, identifier) }.to raise_error(
          JPie::Errors::BadRequestError,
          'Resource identifier object members must be strings'
        )
      end
    end

    context 'with empty type' do
      let(:identifier) { { 'type' => '', 'id' => '1' } }

      it 'raises BadRequestError' do
        expect { controller.send(:validate_resource_identifier, identifier) }.to raise_error(
          JPie::Errors::BadRequestError,
          'Resource identifier object members cannot be empty strings'
        )
      end
    end

    context 'with empty id' do
      let(:identifier) { { 'type' => 'posts', 'id' => '' } }

      it 'raises BadRequestError' do
        expect { controller.send(:validate_resource_identifier, identifier) }.to raise_error(
          JPie::Errors::BadRequestError,
          'Resource identifier object members cannot be empty strings'
        )
      end
    end
  end
end 