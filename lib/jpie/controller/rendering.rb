# frozen_string_literal: true

module JPie
  module Controller
    module Rendering
      def resource_class
        # Default implementation that infers from controller name
        @resource_class ||= infer_resource_class
      end

      def serializer
        @serializer ||= JPie::Serializer.new(resource_class)
      end

      def deserializer
        @deserializer ||= JPie::Deserializer.new(resource_class)
      end

      protected

      def model_class
        resource_class.model
      end

      def render_jsonapi_resource(resource, status: :ok, meta: nil)
        includes = parse_include_params
        json_data = serializer.serialize(resource, context, includes: includes)
        json_data[:meta] = meta if meta

        render json: json_data, status:, content_type: 'application/vnd.api+json'
      end

      def render_jsonapi_resources(resources, status: :ok, meta: nil)
        includes = parse_include_params
        json_data = serializer.serialize(resources, context, includes: includes)
        json_data[:meta] = meta if meta

        render json: json_data, status:, content_type: 'application/vnd.api+json'
      end

      private

      def infer_resource_class
        # Convert controller name to resource class name
        # e.g., "UsersController" -> "UserResource"
        # e.g., "Api::V1::UsersController" -> "UserResource"
        controller_name = self.class.name
        return nil unless controller_name&.end_with?('Controller')

        # Remove "Controller" suffix and any namespace
        base_name = controller_name.split('::').last.chomp('Controller')

        # Convert plural controller name to singular resource name
        # e.g., "Users" -> "User"
        singular_name = base_name.singularize
        resource_class_name = "#{singular_name}Resource"

        # Try to constantize the resource class
        resource_class_name.constantize
      end
    end
  end
end
