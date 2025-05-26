# frozen_string_literal: true

require 'rspec/expectations'

module JPie
  # RSpec matchers and helpers for testing JPie resources
  module RSpec
    # Configure RSpec with JPie helpers and matchers
    def self.configure!
      ::RSpec.configure do |config|
        config.include JPie::RSpec::Matchers
        config.include JPie::RSpec::Helpers
      end
    end

    # Custom matchers for JPie resources
    module Matchers
      extend ::RSpec::Matchers::DSL

      matcher :have_attribute do |attribute_name|
        match do |actual|
          actual.respond_to?(attribute_name) &&
            actual.attributes.key?(attribute_name.to_s)
        end

        failure_message do |actual|
          "expected #{actual.inspect} to have attribute '#{attribute_name}'"
        end
      end

      matcher :have_relationship do |relationship_name|
        match do |actual|
          actual.respond_to?(relationship_name) &&
            actual.relationships.key?(relationship_name.to_s)
        end

        failure_message do |actual|
          "expected #{actual.inspect} to have relationship '#{relationship_name}'"
        end
      end
    end

    # Helper methods for testing JPie resources
    module Helpers
      # Build a JPie resource without saving it
      def build_jpie_resource(type, attributes = {}, relationships = {})
        JPie::Resource.new(
          type: type,
          attributes: attributes,
          relationships: relationships
        )
      end

      # Create a JPie resource and save it
      def create_jpie_resource(type, attributes = {}, relationships = {})
        resource = build_jpie_resource(type, attributes, relationships)
        resource.save
        resource
      end

      # Clean up test data after specs
      def cleanup_jpie_resources(resources)
        Array(resources).each do |resource|
          resource.destroy if resource.persisted?
        rescue StandardError => e
          warn "Failed to cleanup resource #{resource.inspect}: #{e.message}"
        end
      end
    end
  end
end
