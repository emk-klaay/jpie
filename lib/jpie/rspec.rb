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

      # Resource Structure Matchers
      matcher :have_type do |expected_type|
        match do |actual|
          actual.type.to_sym == expected_type.to_sym
        end

        failure_message do |actual|
          "expected #{actual.inspect} to have type '#{expected_type}'"
        end
      end

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

      matcher :have_meta_attribute do |meta_attribute_name|
        match do |actual|
          actual.respond_to?(meta_attribute_name) &&
            actual.meta_hash.key?(meta_attribute_name.to_s)
        end

        failure_message do |actual|
          "expected #{actual.inspect} to have meta attribute '#{meta_attribute_name}'"
        end
      end

      # Meta Field Matchers
      matcher :have_meta do
        match do |actual|
          if actual.is_a?(ActionDispatch::TestResponse)
            JSON.parse(actual.body).key?('meta')
          else
            !actual.meta_hash.empty?
          end
        end

        failure_message do |_actual|
          'expected response to have meta data'
        end
      end

      matcher :have_meta_field do |field_name|
        match do |actual|
          if actual.is_a?(ActionDispatch::TestResponse)
            JSON.parse(actual.body)['meta']&.key?(field_name.to_s)
          else
            actual.meta_hash.key?(field_name.to_s)
          end
        end

        failure_message do |actual|
          "expected #{actual.inspect} to have meta field '#{field_name}'"
        end
      end

      matcher :have_meta_value do |field_name|
        chain :including do |*expected_values|
          @expected_values = expected_values.first
        end

        match do |actual|
          meta_value = if actual.is_a?(ActionDispatch::TestResponse)
                         JSON.parse(actual.body)['meta'][field_name.to_s]
                       else
                         actual.meta_hash[field_name.to_s]
                       end

          if @expected_values.is_a?(Hash)
            @expected_values.all? { |k, v| meta_value[k.to_s] == v }
          else
            meta_value == @expected_values
          end
        end

        failure_message do |actual|
          "expected #{actual.inspect} to have meta value '#{@expected_values}' for field '#{field_name}'"
        end
      end

      # Pagination Matchers
      matcher :be_paginated do
        match do |response|
          JSON.parse(response.body)['meta']&.key?('pagination')
        end

        failure_message do |_actual|
          'expected response to include pagination metadata'
        end
      end

      matcher :have_page_size do |expected_size|
        match do |response|
          JSON.parse(response.body)['data'].size == expected_size
        end

        failure_message do |response|
          actual_size = JSON.parse(response.body)['data'].size
          "expected response to have #{expected_size} items but got #{actual_size}"
        end
      end

      matcher :have_pagination_links do
        chain :including do |*expected_links|
          @expected_links = expected_links
        end

        match do |response|
          json = JSON.parse(response.body)
          if @expected_links
            @expected_links.all? { |link| json['links'].key?(link.to_s) }
          else
            json.key?('links')
          end
        end

        failure_message do |_actual|
          if @expected_links
            "expected response to have pagination links including #{@expected_links.join(', ')}"
          else
            'expected response to have pagination links'
          end
        end
      end

      # Relationship Matchers
      matcher :include_related do |relationship_name|
        match do |response|
          json = JSON.parse(response.body)
          json['included']&.any? { |included| included['type'] == relationship_name.to_s.pluralize }
        end

        failure_message do |_actual|
          "expected response to include related '#{relationship_name}' resources"
        end
      end

      matcher :have_relationship_linkage do |relationship_name|
        chain :with_id do |expected_id|
          @expected_id = expected_id
        end

        match do |actual|
          relationship = actual.relationships[relationship_name.to_s]
          return false unless relationship

          if @expected_id
            relationship['data']['id'] == @expected_id
          else
            relationship.key?('data')
          end
        end

        failure_message do |actual|
          if @expected_id
            "expected #{actual.inspect} to have relationship '#{relationship_name}' with id '#{@expected_id}'"
          else
            "expected #{actual.inspect} to have relationship linkage for '#{relationship_name}'"
          end
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
