# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JPie::Serializer do
  # Test resource using the ActiveRecord User model from database.rb
  let(:test_resource_class) do
    Class.new(JPie::Resource) do
      model User
      attributes :name, :email
      attribute :created_at
    end
  end

  let(:serializer) { described_class.new(test_resource_class) }

  let(:model_instance) do
    User.create!(
      name: 'John Doe',
      email: 'john@example.com',
      created_at: Time.parse('2024-01-01T12:00:00Z')
    )
  end

  let(:model_collection) do
    [
      User.create!(name: 'John Doe', email: 'john@example.com'),
      User.create!(name: 'Jane Smith', email: 'jane@example.com')
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
        expect(data[:id]).to eq(model_instance.id.to_s)
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
        second_item = result[:data].last
        
        expect(first_item[:id]).to eq(model_collection.first.id.to_s)
        expect(first_item[:type]).to eq('users')
        expect(first_item[:attributes]['name']).to eq('John Doe')

        expect(second_item[:id]).to eq(model_collection.last.id.to_s)
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
      # Create user with valid name, then update to nil to test nil handling
      user_with_nil = User.create!(name: 'temp', email: 'test@example.com')
      user_with_nil.update_attribute(:name, nil)
      result = serializer.serialize(user_with_nil)

      expect(result[:data][:attributes][:name]).to be_nil
    end

    it 'handles complex attribute values' do
      user_with_complex_data = User.create!(
        name: 'John',
        email: 'john@example.com',
        created_at: Time.parse('2024-01-01T12:00:00Z')
      )

      result = serializer.serialize(user_with_complex_data)
      expect(result[:data][:attributes]['created-at']).to eq('2024-01-01T12:00:00Z')
    end
  end
end
