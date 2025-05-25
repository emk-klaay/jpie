# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JPie::Configuration do
  let(:config) { described_class.new }

  it 'has default values', :aggregate_failures do
    expect(config.default_page_size).to eq(20)
    expect(config.maximum_page_size).to eq(100)
  end
end

RSpec.describe JPie do
  describe '.configure' do
    it 'yields the configuration' do
      expect { |b| described_class.configure(&b) }.to yield_with_args(described_class.configuration)
    end

    it 'allows setting configuration options' do
      original_page_size = described_class.configuration.default_page_size

      begin
        described_class.configure do |config|
          config.default_page_size = 50
        end

        expect(described_class.configuration.default_page_size).to eq(50)
      ensure
        described_class.configure do |config|
          config.default_page_size = original_page_size
        end
      end
    end
  end
end
