# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JPie::Serializer do
  # Mock model and resource for testing
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
    Class.new(JPie::Resource) do
      model model_class
      attributes :name, :email
      attribute :created_at
    end
  end

  let(:serializer) { described_class.new(test_resource_class) }

  let(:model_instance) do
    mock_model.new(
      id: 1,
      name: 'John Doe',
      email: 'john@example.com',
      created_at: Time.parse('2024-01-01T12:00:00Z')
    )
  end

  let(:model_collection) do
    [
      mock_model.new(id: 1, name: 'John Doe', email: 'john@example.com'),
      mock_model.new(id: 2, name: 'Jane Smith', email: 'jane@example.com')
    ]
  end

  describe '#serialize' do
    context 'with a single object' do
      let(:result) { serializer.serialize(model_instance) }

      it 'returns a JSON:API compliant structure' do
        expect(result).to have_key(:data)
        expect(result[:data]).to be_a(Hash)
      end

      it 'includes the correct id and type' do
        data = result[:data]
        expect(data[:id]).to eq('1')
        expect(data[:type]).to eq('users')
      end

      it 'includes the correct attributes' do
        attributes = result[:data][:attributes]
        expect(attributes).to include(
          'name' => 'John Doe',
          'email' => 'john@example.com'
        )
      end

      it 'formats datetime attributes as ISO8601' do
        attributes = result[:data][:attributes]
        expect(attributes['created-at']).to eq('2024-01-01T12:00:00Z')
      end
    end

    context 'with a collection' do
      let(:result) { serializer.serialize(model_collection) }

      it 'returns a JSON:API compliant collection structure' do
        expect(result).to have_key(:data)
        expect(result[:data]).to be_an(Array)
        expect(result[:data].length).to eq(2)
      end

      it 'includes correct data for each item' do
        first_item = result[:data].first
        expect(first_item[:id]).to eq('1')
        expect(first_item[:type]).to eq('users')
        expect(first_item[:attributes]['name']).to eq('John Doe')

        second_item = result[:data].last
        expect(second_item[:id]).to eq('2')
        expect(second_item[:type]).to eq('users')
        expect(second_item[:attributes]['name']).to eq('Jane Smith')
      end
    end

    context 'with different key formats' do
      before do
        JPie.configure { |config| config.json_key_format = key_format }
      end

      after do
        JPie.configure { |config| config.json_key_format = :dasherized }
      end

      context 'when configured for dasherized keys' do
        let(:key_format) { :dasherized }
        let(:result) { serializer.serialize(model_instance) }

        it 'uses dasherized keys' do
          attributes = result[:data][:attributes]
          expect(attributes).to have_key('created-at')
          expect(attributes).not_to have_key('created_at')
        end
      end

      context 'when configured for underscored keys' do
        let(:key_format) { :underscored }
        let(:result) { serializer.serialize(model_instance) }

        it 'uses underscored keys' do
          attributes = result[:data][:attributes]
          expect(attributes).to have_key('created_at')
          expect(attributes).not_to have_key('created-at')
        end
      end

      context 'when configured for camelized keys' do
        let(:key_format) { :camelized }
        let(:result) { serializer.serialize(model_instance) }

        it 'uses camelized keys' do
          attributes = result[:data][:attributes]
          expect(attributes).to have_key('createdAt')
          expect(attributes).not_to have_key('created_at')
        end
      end
    end
  end

  describe 'context passing' do
    it 'passes context to resource initialization' do
      context = { current_user: 'admin' }
      expect(test_resource_class).to receive(:new).with(model_instance, context).and_call_original
      
      serializer.serialize(model_instance, context)
    end
  end

  describe 'error handling' do
    it 'handles nil objects gracefully' do
      result = serializer.serialize(nil)
      expect(result[:data]).to be_nil
    end

    it 'handles empty collections' do
      result = serializer.serialize([])
      expect(result[:data]).to eq([])
    end
  end

  describe 'attribute formatting' do
    it 'handles nil attribute values' do
      user_with_nil = mock_model.new(id: 1, name: nil, email: 'test@example.com')
      result = serializer.serialize(user_with_nil)
      
      expect(result[:data][:attributes][:name]).to be_nil
    end

    it 'handles complex attribute values' do
      user_with_complex_data = mock_model.new(
        id: 1,
        name: 'John',
        email: 'john@example.com',
        created_at: Time.parse('2024-01-01T12:00:00Z')
      )
      
      result = serializer.serialize(user_with_complex_data)
      expect(result[:data][:attributes]['created-at']).to eq('2024-01-01T12:00:00Z')
    end
  end
end
