# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JPie::Configuration do
  let(:config) { described_class.new }

  describe '#initialize' do
    it 'sets default values' do
      expect(config.json_key_format).to eq(:dasherized)
      expect(config.default_page_size).to eq(20)
      expect(config.maximum_page_size).to eq(1000)
    end
  end

  describe '#json_key_format=' do
    it 'accepts valid formats' do
      %i[dasherized underscored camelized].each do |format|
        expect { config.json_key_format = format }.not_to raise_error
        expect(config.json_key_format).to eq(format)
      end
    end

    it 'raises error for invalid format' do
      expect { config.json_key_format = :invalid }.to raise_error(ArgumentError)
    end

    it 'does not accept string values directly' do
      # Note: The implementation doesn't convert strings to symbols
      expect { config.json_key_format = 'camelized' }.to raise_error(ArgumentError)
    end
  end

  describe '#default_page_size=' do
    it 'accepts valid page sizes' do
      config.default_page_size = 50
      expect(config.default_page_size).to eq(50)
    end

    # Note: The current implementation doesn't validate page sizes
    it 'accepts any value (no validation)' do
      config.default_page_size = -1
      expect(config.default_page_size).to eq(-1)
    end
  end

  describe '#maximum_page_size=' do
    it 'accepts valid page sizes' do
      config.maximum_page_size = 200
      expect(config.maximum_page_size).to eq(200)
    end

    # Note: The current implementation doesn't validate page sizes
    it 'accepts any value (no validation)' do
      config.maximum_page_size = -1
      expect(config.maximum_page_size).to eq(-1)
    end
  end
end

RSpec.describe JPie do
  describe '.configure' do
    it 'yields the configuration' do
      expect { |b| JPie.configure(&b) }.to yield_with_args(JPie.configuration)
    end

    it 'allows setting configuration options' do
      original_format = JPie.configuration.json_key_format
      original_page_size = JPie.configuration.default_page_size
      original_max_size = JPie.configuration.maximum_page_size

      JPie.configure do |config|
        config.json_key_format = :underscored
        config.default_page_size = 25
        config.maximum_page_size = 200
      end

      expect(JPie.configuration.json_key_format).to eq(:underscored)
      expect(JPie.configuration.default_page_size).to eq(25)
      expect(JPie.configuration.maximum_page_size).to eq(200)

      # Reset to original values
      JPie.configure do |config|
        config.json_key_format = original_format
        config.default_page_size = original_page_size
        config.maximum_page_size = original_max_size
      end
    end
  end

  describe '.configuration' do
    it 'returns a Configuration instance' do
      expect(JPie.configuration).to be_a(JPie::Configuration)
    end

    it 'returns the same instance on multiple calls' do
      expect(JPie.configuration).to be(JPie.configuration)
    end
  end
end 