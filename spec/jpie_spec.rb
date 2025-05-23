# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JPie do
  it 'has a version number', :aggregate_failures do
    expect(JPie::VERSION).not_to be_nil
    expect(JPie::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  describe 'module structure' do
    it 'defines all expected classes', :aggregate_failures do
      expect(defined?(JPie::Resource)).to be_truthy
      expect(defined?(JPie::Serializer)).to be_truthy
      expect(defined?(JPie::Deserializer)).to be_truthy
      expect(defined?(JPie::Controller)).to be_truthy
      expect(defined?(JPie::Configuration)).to be_truthy
      expect(defined?(JPie::Errors)).to be_truthy
    end

    it 'has proper class hierarchy', :aggregate_failures do
      expect(JPie::Errors::BadRequestError.ancestors).to include(JPie::Errors::Error)
      expect(JPie::Controller).to be_a(Module)
    end
  end

  describe 'autoloading' do
    it 'loads all components when required', :aggregate_failures do
      # This test ensures that require 'jpie' loads all necessary components
      expect { JPie::Resource }.not_to raise_error
      expect { JPie::Serializer }.not_to raise_error
      expect { JPie::Deserializer }.not_to raise_error
      expect { JPie::Controller }.not_to raise_error
      expect { JPie::Configuration }.not_to raise_error
      expect { JPie::Errors::Error }.not_to raise_error
    end
  end
end
