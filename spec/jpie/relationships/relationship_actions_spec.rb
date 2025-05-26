# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JPie::Controller::RelationshipActions do
  let(:controller_class) { create_test_controller('TestController', PostResource) }
  let(:controller) { controller_class.new }
  let(:user) { User.create!(name: 'Test User', email: 'test@example.com') }
  let(:post) { Post.create!(title: 'Test Post', content: 'Content', user:) }
  let(:reply1) { Post.create!(title: 'Reply 1', content: 'Reply 1', parent_post: post) }
  let(:reply2) { Post.create!(title: 'Reply 2', content: 'Reply 2', parent_post: post) }
  let(:tag1) { Tag.create!(name: 'Tag 1') }
  let(:tag2) { Tag.create!(name: 'Tag 2') }
  let(:content_type) { 'application/vnd.api+json' }
  let(:request_body) { '{}' }
  let(:params) { { id: post.id } }

  before do
    controller.params = params
    controller.request.content_type = content_type
    controller.request.body = request_body
    controller.request.method = request_method if defined?(request_method)
  end

  describe '#relationship_show' do
    let(:params) { { id: post.id, relationship_name: relationship_name } }

    context 'with to-one relationship' do
      let(:relationship_name) { 'user' }

      it 'returns the relationship data' do
        result = controller.relationship_show
        expect(result[:json]).to eq(
          data: {
            type: 'users',
            id: user.id.to_s
          }
        )
      end

      context 'when relationship is nil' do
        before { post.update!(user: nil) }

        it 'returns null data' do
          result = controller.relationship_show
          expect(result[:json]).to eq(data: nil)
        end
      end
    end

    context 'with to-many relationship' do
      let(:relationship_name) { 'replies' }

      before { [reply1, reply2] }

      it 'returns the relationship data as an array' do
        result = controller.relationship_show
        expect(result[:json]).to eq(
          data: [
            { type: 'posts', id: reply1.id.to_s },
            { type: 'posts', id: reply2.id.to_s }
          ]
        )
      end

      context 'when relationship is empty' do
        before { post.replies.clear }

        it 'returns empty array data' do
          result = controller.relationship_show
          expect(result[:json]).to eq(data: [])
        end
      end
    end

    context 'with invalid relationship' do
      let(:relationship_name) { 'invalid' }

      it 'raises NotFoundError' do
        expect { controller.relationship_show }.to raise_error(
          JPie::Errors::NotFoundError,
          "Relationship 'invalid' does not exist for PostResource"
        )
      end
    end
  end

  describe '#relationship_update' do
    let(:params) { { id: post.id, relationship_name: relationship_name } }
    let(:request_method) { 'PATCH' }

    context 'with to-one relationship' do
      let(:relationship_name) { 'user' }
      let(:new_user) { User.create!(name: 'New User', email: 'new@example.com') }

      context 'when replacing with new resource' do
        let(:request_body) do
          {
            data: {
              type: 'users',
              id: new_user.id.to_s
            }
          }.to_json
        end

        it 'updates the relationship' do
          controller.relationship_update
          post.reload
          expect(post.user).to eq(new_user)
        end
      end

      context 'when setting to null' do
        let(:request_body) { { data: nil }.to_json }

        it 'clears the relationship' do
          controller.relationship_update
          post.reload
          expect(post.user).to be_nil
        end
      end

      context 'with invalid resource type' do
        let(:request_body) do
          {
            data: {
              type: 'posts',
              id: reply1.id.to_s
            }
          }.to_json
        end

        it 'raises NotFoundError' do
          expect { controller.relationship_update }.to raise_error(
            JPie::Errors::NotFoundError,
            /Related resource not found: Invalid resource type for relationship/
          )
        end
      end

      context 'with non-existent resource' do
        let(:request_body) do
          {
            data: {
              type: 'users',
              id: '999999'
            }
          }.to_json
        end

        it 'raises NotFoundError' do
          expect { controller.relationship_update }.to raise_error(
            JPie::Errors::NotFoundError,
            /Related resource not found: users#999999/
          )
        end
      end
    end

    context 'with to-many relationship' do
      let(:relationship_name) { 'replies' }
      let(:new_reply) { Post.create!(title: 'New Reply', content: 'New Reply') }

      before { [reply1, reply2] }

      context 'when replacing all resources' do
        let(:request_body) do
          {
            data: [
              { type: 'posts', id: new_reply.id.to_s }
            ]
          }.to_json
        end

        it 'replaces all relationships' do
          controller.relationship_update
          post.reload
          expect(post.replies).to contain_exactly(new_reply)
        end
      end

      context 'when setting to empty array' do
        let(:request_body) { { data: [] }.to_json }

        it 'removes all relationships' do
          controller.relationship_update
          post.reload
          expect(post.replies).to be_empty
        end
      end

      context 'when trying to set to null' do
        let(:request_body) { { data: nil }.to_json }

        it 'raises an error' do
          expect { controller.relationship_update }.to raise_error(
            JPie::Errors::BadRequestError,
            'Cannot set a to-many relationship to null'
          )
        end
      end

      context 'with invalid data type' do
        let(:request_body) { { data: 'invalid' }.to_json }

        it 'raises BadRequestError' do
          expect { controller.relationship_update }.to raise_error(
            JPie::Errors::BadRequestError,
            'The value of data must be an array for to-many relationships'
          )
        end
      end

      context 'with invalid resource type' do
        let(:request_body) do
          {
            data: [
              { type: 'users', id: user.id.to_s }
            ]
          }.to_json
        end

        it 'raises NotFoundError' do
          expect { controller.relationship_update }.to raise_error(
            JPie::Errors::NotFoundError,
            /Related resource not found: Invalid resource type for relationship/
          )
        end
      end
    end
  end

  describe '#relationship_create' do
    let(:params) { { id: post.id, relationship_name: relationship_name } }
    let(:request_method) { 'POST' }

    context 'with to-many relationship' do
      let(:relationship_name) { 'replies' }
      let(:new_reply) { Post.create!(title: 'New Reply', content: 'New Reply') }

      before { [reply1] }

      context 'when adding new resources' do
        let(:request_body) do
          {
            data: [
              { type: 'posts', id: new_reply.id.to_s }
            ]
          }.to_json
        end

        it 'adds the relationships without removing existing ones' do
          controller.relationship_create
          post.reload
          expect(post.replies).to contain_exactly(reply1, new_reply)
        end
      end

      context 'with invalid data type' do
        let(:request_body) { { data: { type: 'posts', id: new_reply.id.to_s } }.to_json }

        it 'raises BadRequestError' do
          expect { controller.relationship_create }.to raise_error(
            JPie::Errors::BadRequestError,
            'The value of data must be an array for to-many relationships'
          )
        end
      end

      context 'with invalid resource type' do
        let(:request_body) do
          {
            data: [
              { type: 'users', id: user.id.to_s }
            ]
          }.to_json
        end

        it 'raises NotFoundError' do
          expect { controller.relationship_create }.to raise_error(
            JPie::Errors::NotFoundError,
            /Related resource not found: Invalid resource type for relationship/
          )
        end
      end
    end

    context 'with to-one relationship' do
      let(:relationship_name) { 'user' }
      let(:request_body) do
        {
          data: { type: 'users', id: user.id.to_s }
        }.to_json
      end

      it 'raises an error' do
        expect { controller.relationship_create }.to raise_error(
          JPie::Errors::BadRequestError,
          'POST is only supported for to-many relationships'
        )
      end
    end
  end

  describe '#relationship_destroy' do
    let(:params) { { id: post.id, relationship_name: relationship_name } }
    let(:request_method) { 'DELETE' }

    context 'with to-many relationship' do
      let(:relationship_name) { 'replies' }

      before { [reply1, reply2] }

      context 'when removing specific resources' do
        let(:request_body) do
          {
            data: [
              { type: 'posts', id: reply1.id.to_s }
            ]
          }.to_json
        end

        it 'removes only the specified relationships' do
          controller.relationship_destroy
          post.reload
          expect(post.replies).to contain_exactly(reply2)
        end
      end

      context 'with invalid data type' do
        let(:request_body) { { data: { type: 'posts', id: reply1.id.to_s } }.to_json }

        it 'raises BadRequestError' do
          expect { controller.relationship_destroy }.to raise_error(
            JPie::Errors::BadRequestError,
            'The value of data must be an array for to-many relationships'
          )
        end
      end

      context 'with invalid resource type' do
        let(:request_body) do
          {
            data: [
              { type: 'users', id: user.id.to_s }
            ]
          }.to_json
        end

        it 'raises NotFoundError' do
          expect { controller.relationship_destroy }.to raise_error(
            JPie::Errors::NotFoundError,
            /Related resource not found: Invalid resource type for relationship/
          )
        end
      end
    end

    context 'with to-one relationship' do
      let(:relationship_name) { 'user' }
      let(:request_body) do
        {
          data: { type: 'users', id: user.id.to_s }
        }.to_json
      end

      it 'raises an error' do
        expect { controller.relationship_destroy }.to raise_error(
          JPie::Errors::BadRequestError,
          'DELETE is only supported for to-many relationships'
        )
      end
    end
  end

  describe '#parse_relationship_data' do
    let(:request_body) { { data: { type: 'users', id: '1' } }.to_json }

    it 'parses and returns the data member' do
      expect(controller.send(:parse_relationship_data)).to eq(
        'type' => 'users',
        'id' => '1'
      )
    end

    context 'when data member is missing' do
      let(:request_body) { '{}' }

      it 'raises BadRequestError' do
        expect { controller.send(:parse_relationship_data) }.to raise_error(
          JPie::Errors::BadRequestError,
          'Request must include a "data" member'
        )
      end
    end
  end

  describe '#infer_type' do
    it 'converts model class name to JSON:API type' do
      expect(controller.send(:infer_type, user)).to eq('users')
      expect(controller.send(:infer_type, post)).to eq('posts')
    end
  end

  describe '#infer_model_class_from_type' do
    it 'converts JSON:API type to model class' do
      expect(controller.send(:infer_model_class_from_type, 'users')).to eq(User)
      expect(controller.send(:infer_model_class_from_type, 'posts')).to eq(Post)
    end
  end
end 