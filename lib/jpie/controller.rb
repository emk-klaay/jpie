# frozen_string_literal: true

require 'active_support/concern'

module JPie
  module Controller
    extend ActiveSupport::Concern

    included do
      rescue_from JPie::Errors::Error, with: :render_jsonapi_error

      if defined?(ActiveRecord)
        rescue_from ActiveRecord::RecordNotFound, with: :render_not_found_error
        rescue_from ActiveRecord::RecordInvalid, with: :render_validation_error
      end
    end

    class_methods do
      def jsonapi_resource(resource_class)
        setup_jsonapi_resource(resource_class)
      end

      private

      def setup_jsonapi_resource(resource_class)
        define_method :resource_class do
          resource_class
        end

        # Define automatic CRUD methods
        define_automatic_crud_methods(resource_class)
      end

      def define_automatic_crud_methods(resource_class)
        define_index_method(resource_class)
        define_show_method(resource_class)
        define_create_method(resource_class)
        define_update_method(resource_class)
        define_destroy_method(resource_class)
      end

      def define_index_method(resource_class)
        define_method :index do
          resources = resource_class.scope(context)
          render_jsonapi_resources(resources)
        end
      end

      def define_show_method(resource_class)
        define_method :show do
          resource = resource_class.scope(context).find(params[:id])
          render_jsonapi_resource(resource)
        end
      end

      def define_create_method(resource_class)
        define_method :create do
          attributes = deserialize_params
          resource = resource_class.model.create!(attributes)
          render_jsonapi_resource(resource, status: :created)
        end
      end

      def define_update_method(resource_class)
        define_method :update do
          resource = resource_class.scope(context).find(params[:id])
          attributes = deserialize_params
          resource.update!(attributes)
          render_jsonapi_resource(resource)
        end
      end

      def define_destroy_method(resource_class)
        define_method :destroy do
          resource = resource_class.scope(context).find(params[:id])
          resource.destroy!
          head :no_content
        end
      end
    end

    # These methods can still be called manually or used to override defaults
    def index
      resources = resource_class.scope(context)
      render_jsonapi_resources(resources)
    end

    def show
      resource = resource_class.scope(context).find(params[:id])
      render_jsonapi_resource(resource)
    end

    def create
      attributes = deserialize_params
      resource = model_class.create!(attributes)
      render_jsonapi_resource(resource, status: :created)
    end

    def update
      resource = resource_class.scope(context).find(params[:id])
      attributes = deserialize_params
      resource.update!(attributes)
      render_jsonapi_resource(resource)
    end

    def destroy
      resource = resource_class.scope(context).find(params[:id])
      resource.destroy!
      head :no_content
    end

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

    def deserialize_params
      deserializer.deserialize(request.body.read, context)
    rescue JSON::ParserError => e
      raise JPie::Errors::BadRequestError.new(detail: "Invalid JSON: #{e.message}")
    end

    def context
      @context ||= build_context
    end

    def build_context
      {
        current_user: try(:current_user),
        controller: self,
        action: action_name
      }
    end

    def parse_include_params
      params[:include]&.split(',')&.map(&:strip) || []
    end

    private

    def render_jsonapi_error(error)
      render json: { errors: [error.to_hash] },
             status: error.status,
             content_type: 'application/vnd.api+json'
    end

    def render_not_found_error(error)
      json_error = JPie::Errors::NotFoundError.new(detail: error.message)
      render_jsonapi_error(json_error)
    end

    def render_validation_error(error)
      errors = error.record.errors.full_messages.map do
        JPie::Errors::ValidationError.new(detail: it).to_hash
      end

      render json: { errors: },
             status: :unprocessable_entity,
             content_type: 'application/vnd.api+json'
    end

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
