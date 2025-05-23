# frozen_string_literal: true

require 'rails/generators/base'

module JPie
  module Generators
    class ResourceGenerator < Rails::Generators::NamedBase
      desc 'Generate a JPie resource class'

      argument :attributes, type: :array, default: [], banner: 'field:type field:type'

      class_option :model, type: :string, desc: 'Model class to associate with this resource'

      def create_resource_file
        template 'resource.rb.erb', File.join('app/resources', "#{file_name}_resource.rb")
      end

      private

      def model_class_name
        options[:model] || class_name
      end

      def resource_attributes
        return [] if attributes.empty?

        attributes.map(&:name)
      end

      def template_path
        File.expand_path('templates', __dir__)
      end

      def source_root
        template_path
      end
    end
  end
end
