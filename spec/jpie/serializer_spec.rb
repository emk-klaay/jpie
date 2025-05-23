# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JPie::Serializer do
  let(:serializer) { described_class.new(UserResource) }

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

      it 'returns JSON:API compliant structure' do
        expect(result).to have_key(:data)
      end

      it 'returns hash data for single object' do
        expect(result[:data]).to be_a(Hash)
      end

      it 'includes correct id' do
        data = result[:data]
        expect(data[:id]).to eq(model_instance.id.to_s)
      end

      it 'includes correct type' do
        data = result[:data]
        expect(data[:type]).to eq('users')
      end

      it 'includes correct attributes' do
        attributes = result[:data][:attributes]
        expect(attributes).to include(
          'name' => 'John Doe',
          'email' => 'john@example.com'
        )
      end

      it 'excludes timestamps from attributes', :aggregate_failures do
        attributes = result[:data][:attributes]
        expect(attributes).not_to have_key('created_at')
        expect(attributes).not_to have_key('updated_at')
      end

      it 'includes meta data' do
        expect(result[:data]).to have_key(:meta)
      end

      it 'includes timestamps in meta', :aggregate_failures do
        meta = result[:data][:meta]
        expect(meta).to have_key('created_at')
        expect(meta).to have_key('updated_at')
      end

      it 'formats datetime meta attributes as ISO8601' do
        meta = result[:data][:meta]
        expect(meta['created_at']).to eq('2024-01-01T12:00:00Z')
      end
    end

    context 'with a collection' do
      let(:result) { serializer.serialize(model_collection) }

      it 'returns JSON:API compliant collection structure' do
        expect(result).to have_key(:data)
      end

      it 'returns array data for collection' do
        expect(result[:data]).to be_an(Array)
      end

      it 'returns correct number of items' do
        expect(result[:data].length).to eq(2)
      end

      it 'includes correct data for first item', :aggregate_failures do
        first_item = result[:data].first

        expect(first_item[:id]).to eq(model_collection.first.id.to_s)
        expect(first_item[:type]).to eq('users')
        expect(first_item[:attributes]['name']).to eq('John Doe')
      end

      it 'includes correct data for second item', :aggregate_failures do
        second_item = result[:data].last

        expect(second_item[:id]).to eq(model_collection.last.id.to_s)
        expect(second_item[:type]).to eq('users')
        expect(second_item[:attributes]['name']).to eq('Jane Smith')
      end

      it 'includes meta data for each item', :aggregate_failures do
        result[:data].each do |item|
          expect(item).to have_key(:meta)
          expect(item[:meta]).to have_key('created_at')
          expect(item[:meta]).to have_key('updated_at')
        end
      end
    end
  end

  describe 'context passing' do
    it 'passes context to resource initialization' do
      context = { current_user: 'admin' }
      expect(UserResource).to receive(:new).with(model_instance, context).and_call_original

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

    it 'handles complex meta values' do
      user_with_complex_data = User.create!(
        name: 'John',
        email: 'john@example.com',
        created_at: Time.parse('2024-01-01T12:00:00Z')
      )

      result = serializer.serialize(user_with_complex_data)
      expect(result[:data][:meta]['created_at']).to eq('2024-01-01T12:00:00Z')
    end
  end
end
