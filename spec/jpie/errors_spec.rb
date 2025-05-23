# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JPie::Errors do
  describe JPie::Errors::Error do
    let(:error) { described_class.new(status: 500, title: 'Test Error', detail: 'Test detail', source: { pointer: '/data' }) }

    describe '#initialize' do
      it 'sets values correctly' do
        expect(error.status).to eq(500)
        expect(error.code).to be_nil
        expect(error.title).to eq('Test Error')
        expect(error.detail).to eq('Test detail')
        expect(error.source).to eq({ pointer: '/data' })
      end
    end

    describe '#to_hash' do
      it 'returns a hash representation' do
        hash = error.to_hash
        expect(hash).to include(
          status: '500',
          title: 'Test Error',
          detail: 'Test detail',
          source: { pointer: '/data' }
        )
        expect(hash).not_to have_key(:code)
      end

      it 'excludes nil values' do
        minimal_error = described_class.new(status: 500, title: 'Minimal')
        hash = minimal_error.to_hash
        expect(hash).not_to have_key(:detail)
        expect(hash).not_to have_key(:source)
        expect(hash).not_to have_key(:code)
      end
    end
  end

  describe JPie::Errors::BadRequestError do
    let(:error) { described_class.new(detail: 'Invalid request') }

    it 'has correct status' do
      expect(error.status).to eq(400)
    end

    it 'has correct title' do
      expect(error.title).to eq('Bad Request')
    end

    it 'includes detail in hash' do
      hash = error.to_hash
      expect(hash[:status]).to eq('400')
      expect(hash[:detail]).to eq('Invalid request')
    end
  end

  describe JPie::Errors::UnauthorizedError do
    let(:error) { described_class.new }

    it 'has correct status' do
      expect(error.status).to eq(401)
    end

    it 'has correct title' do
      expect(error.title).to eq('Unauthorized')
    end
  end

  describe JPie::Errors::ForbiddenError do
    let(:error) { described_class.new }

    it 'has correct status' do
      expect(error.status).to eq(403)
    end

    it 'has correct title' do
      expect(error.title).to eq('Forbidden')
    end
  end

  describe JPie::Errors::NotFoundError do
    let(:error) { described_class.new(detail: 'Resource not found') }

    it 'has correct status' do
      expect(error.status).to eq(404)
    end

    it 'has correct title' do
      expect(error.title).to eq('Not Found')
    end
  end

  describe JPie::Errors::ValidationError do
    let(:error) { described_class.new(detail: 'Name is required', source: { pointer: '/data/attributes/name' }) }

    it 'has correct status' do
      expect(error.status).to eq(422)
    end

    it 'has correct title' do
      expect(error.title).to eq('Validation Error')
    end

    it 'includes source in hash' do
      hash = error.to_hash
      expect(hash[:source]).to eq({ pointer: '/data/attributes/name' })
    end
  end

  describe JPie::Errors::InternalServerError do
    let(:error) { described_class.new }

    it 'has correct status' do
      expect(error.status).to eq(500)
    end

    it 'has correct title' do
      expect(error.title).to eq('Internal Server Error')
    end
  end

  describe 'error hierarchy' do
    it 'all error classes inherit from Error' do
      error_classes = [
        JPie::Errors::BadRequestError,
        JPie::Errors::UnauthorizedError,
        JPie::Errors::ForbiddenError,
        JPie::Errors::NotFoundError,
        JPie::Errors::ValidationError,
        JPie::Errors::InternalServerError
      ]

      error_classes.each do |error_class|
        expect(error_class.ancestors).to include(JPie::Errors::Error)
      end
    end
  end
end 