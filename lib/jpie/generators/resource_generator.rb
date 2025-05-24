# frozen_string_literal: true

require 'rails/generators/base'

module JPie
  module Generators
    class ResourceGenerator < Rails::Generators::NamedBase
      source_root File.expand_path('templates', __dir__)

      desc 'Generate a JPie resource class'

      argument :attributes, type: :array, default: [], banner: 'field:type field:type'

      class_option :model, type: :string,
                           desc: 'Model class to associate with this resource (defaults to inferred model)'
      class_option :relationships, type: :array, default: [],
                                   desc: 'Relationships to include (e.g., has_many:posts has_one:user)'
      class_option :meta_attributes, type: :array, default: [],
                                     desc: 'Meta attributes to include (e.g., created_at updated_at)'
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
        return [] if attributes.empty?

        # Parse attributes and separate regular attributes from meta attributes
        attributes.reject { |attr| meta_attribute?(attr) }.map(&:name)
      end

      def meta_attributes_list
        # Combine CLI meta attributes with attributes marked as meta
        cli_meta = options[:meta_attributes] || []
        parsed_meta = attributes.select { |attr| meta_attribute?(attr) }.map(&:name)

        (cli_meta + parsed_meta).uniq
      end

      def relationships_list
        options[:relationships] || []
      end

      def parse_relationships
        relationships_list.map do |rel|
          if rel.include?(':')
            type, name = rel.split(':', 2)
            { type: type, name: name }
          else
            # Default to has_many if no type specified
            { type: 'has_many', name: rel }
          end
        end
      end

      def meta_attribute?(attr)
        # Check if attribute name suggests it's a meta attribute
        meta_names = %w[created_at updated_at deleted_at published_at]
        meta_names.include?(attr.name)
      end
    end
  end
end
