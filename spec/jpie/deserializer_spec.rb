# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JPie::Deserializer do
  let(:mock_model) do
    Class.new do
      def self.model_name
        OpenStruct.new(plural: 'users')
      end
    end
  end

  let(:test_resource_class) do
    model_class = mock_model
    Class.new(JPie::Resource) do
      model model_class
      attributes :name, :email
      attribute :created_at
    end
  end

  let(:deserializer) { described_class.new(test_resource_class) }

  describe '#deserialize' do
    context 'with valid single resource JSON:API data' do
      let(:json_data) do
        {
          'data' => {
            'type' => 'users',
            'id' => '1',
            'attributes' => {
              'name' => 'John Doe',
              'email' => 'john@example.com',
              'created-at' => '2024-01-01T12:00:00Z'
            }
          }
        }
      end

      let(:result) { deserializer.deserialize(json_data) }

      it 'returns a hash with the correct attributes' do
        expect(result).to be_a(ActiveSupport::HashWithIndifferentAccess)
        expect(result['name']).to eq('John Doe')
        expect(result['email']).to eq('john@example.com')
        expect(result['id']).to eq('1')
      end

      it 'parses datetime strings' do
        expect(result['created_at']).to be_a(Time)
        expect(result['created_at']).to eq(Time.parse('2024-01-01T12:00:00Z'))
      end

      it 'converts dasherized keys to underscored' do
        expect(result).to have_key('created_at')
        expect(result).not_to have_key('created-at')
      end
    end

    context 'with valid collection JSON:API data' do
      let(:json_data) do
        {
          'data' => [
            {
              'type' => 'users',
              'id' => '1',
              'attributes' => {
                'name' => 'John Doe',
                'email' => 'john@example.com'
              }
            },
            {
              'type' => 'users',
              'id' => '2',
              'attributes' => {
                'name' => 'Jane Smith',
                'email' => 'jane@example.com'
              }
            }
          ]
        }
      end

      let(:result) { deserializer.deserialize(json_data) }

      it 'returns an array of attribute hashes' do
        expect(result).to be_an(Array)
        expect(result.length).to eq(2)

        expect(result.first['name']).to eq('John Doe')
        expect(result.first['id']).to eq('1')

        expect(result.last['name']).to eq('Jane Smith')
        expect(result.last['id']).to eq('2')
      end
    end

    context 'with JSON string input' do
      let(:json_string) do
        {
          'data' => {
            'type' => 'users',
            'attributes' => {
              'name' => 'John Doe'
            }
          }
        }.to_json
      end

      it 'parses the JSON string and deserializes' do
        result = deserializer.deserialize(json_string)
        expect(result['name']).to eq('John Doe')
      end
    end

    context 'with invalid JSON:API structure' do
      it 'raises an error when data key is missing' do
        invalid_data = { 'invalid' => 'structure' }

        expect do
          deserializer.deserialize(invalid_data)
        end.to raise_error(JPie::Errors::BadRequestError, /Invalid JSON:API structure/)
      end

      it 'raises an error when resource data is invalid' do
        invalid_data = {
          'data' => {
            'attributes' => { 'name' => 'John' }
            # Missing required 'type' field
          }
        }

        expect do
          deserializer.deserialize(invalid_data)
        end.to raise_error(JPie::Errors::BadRequestError, /Resource data must include "type"/)
      end
    end

    context 'with wrong type' do
      let(:json_data) do
        {
          'data' => {
            'type' => 'posts', # Wrong type
            'attributes' => {
              'name' => 'John Doe'
            }
          }
        }
      end

      it 'raises an error for type mismatch' do
        expect do
          deserializer.deserialize(json_data)
        end.to raise_error(JPie::Errors::BadRequestError, /Expected type 'users', got 'posts'/)
      end
    end

    context 'with invalid JSON string' do
      it 'raises an error for malformed JSON' do
        expect do
          deserializer.deserialize('{ invalid json }')
        end.to raise_error(JPie::Errors::BadRequestError, /Invalid JSON/)
      end
    end

    context 'with filtered attributes' do
      let(:json_data) do
        {
          'data' => {
            'type' => 'users',
            'attributes' => {
              'name' => 'John Doe',
              'email' => 'john@example.com',
              'unauthorized_field' => 'should be filtered out'
            }
          }
        }
      end

      it 'only includes attributes defined in the resource class' do
        result = deserializer.deserialize(json_data)
        expect(result).to have_key('name')
        expect(result).to have_key('email')
        expect(result).not_to have_key('unauthorized_field')
      end
    end
  end
end
