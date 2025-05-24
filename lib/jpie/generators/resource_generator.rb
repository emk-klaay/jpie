# frozen_string_literal: true

require 'rails/generators/base'

module JPie
  module Generators
    class ResourceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      desc 'Generate a JPie resource class with semantic field definitions'

      argument :field_definitions, type: :array, default: [],
                                   banner: 'attribute:field meta:field relationship:type:field'

      class_option :model, type: :string,
                           desc: 'Model class to associate with this resource (defaults to inferred model)'
      class_option :skip_model, type: :boolean, default: false,
                                desc: 'Skip explicit model declaration (use automatic inference)'

      def create_resource_file
        template 'resource.rb.erb', File.join('app/resources', "#{file_name}_resource.rb")
      end

      private

      def model_class_name
        options[:model] || class_name
      end

      def needs_explicit_model?
        # Only need explicit model declaration if:
        # 1. User explicitly provided a different model name, OR
        # 2. User didn't use --skip-model flag AND the model name differs from the inferred name
        return false if options[:skip_model]
        return true if options[:model] && options[:model] != class_name

        # For standard naming (UserResource -> User), we can skip the explicit declaration
        false
      end

      def resource_attributes
        parse_field_definitions.fetch(:attributes, [])
      end

      def meta_attributes_list
        parse_field_definitions.fetch(:meta_attributes, [])
      end

      def relationships_list
        parse_field_definitions.fetch(:relationships, [])
      end

      def parse_relationships
        relationships_list.map do |rel|
          # rel is already a hash with :type and :name from parse_field_definitions
          rel
        end
      end

      def parse_field_definitions
        return @parsed_definitions if @parsed_definitions

        @parsed_definitions = { attributes: [], meta_attributes: [], relationships: [] }

        field_definitions.each do |definition|
          process_field_definition(definition)
        end

        @parsed_definitions
      end

      def process_field_definition(definition)
        case definition
        when /^attribute:(.+)$/
          @parsed_definitions[:attributes] << ::Regexp.last_match(1)
        when /^meta:(.+)$/
          @parsed_definitions[:meta_attributes] << ::Regexp.last_match(1)
        when /^relationship:(.+):(.+)$/, /^(has_many|has_one|belongs_to):(.+)$/
          add_relationship(::Regexp.last_match(1), ::Regexp.last_match(2))
        when /^(.+):(.+)$/
          process_legacy_field(::Regexp.last_match(1))
        else
          process_plain_field(definition)
        end
      end

      def add_relationship(type, name)
        @parsed_definitions[:relationships] << { type: type, name: name }
      end

      def process_legacy_field(field_name)
        # Legacy support: field:type format - treat as attribute and ignore type
        if meta_attribute_name?(field_name)
          @parsed_definitions[:meta_attributes] << field_name
        else
          @parsed_definitions[:attributes] << field_name
        end
      end

      def process_plain_field(field_name)
        # Plain field name - treat as attribute
        if meta_attribute_name?(field_name)
          @parsed_definitions[:meta_attributes] << field_name
        else
          @parsed_definitions[:attributes] << field_name
        end
      end

      def meta_attribute_name?(name)
        # Check if field name suggests it's a meta attribute
        meta_names = %w[created_at updated_at deleted_at published_at archived_at]
        meta_names.include?(name)
      end
    end
  end
end
