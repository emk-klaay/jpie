# frozen_string_literal: true

require 'active_support/concern'

module JPie
  module Controller
    extend ActiveSupport::Concern

    included do
      rescue_from JPie::Errors::Error, with: :render_jsonapi_error
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found_error
      rescue_from ActiveRecord::RecordInvalid, with: :render_validation_error
    end

    class_methods do
      def jsonapi_resource(resource_class)
        define_method :resource_class do
          resource_class
        end

        define_method :serializer do
          @serializer ||= JPie::Serializer.new(resource_class)
        end

        define_method :deserializer do
          @deserializer ||= JPie::Deserializer.new(resource_class)
        end
      end
    end

    protected

    def render_jsonapi_resource(resource, status: :ok, meta: nil)
      json_data = serializer.serialize(resource, context)
      json_data[:meta] = meta if meta

      render json: json_data, status:, content_type: 'application/vnd.api+json'
    end

    def render_jsonapi_resources(resources, status: :ok, meta: nil)
      json_data = serializer.serialize(resources, context)
      json_data[:meta] = meta if meta

      render json: json_data, status:, content_type: 'application/vnd.api+json'
    end

    def deserialize_params
      deserializer.deserialize(request.body.read, context)
    rescue JSON::ParserError
      raise JPie::Errors::BadRequestError.new(detail: 'Invalid JSON')
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
      errors = error.record.errors.full_messages.map do |message|
        JPie::Errors::ValidationError.new(detail: message).to_hash
      end

      render json: { errors: },
             status: :unprocessable_entity,
             content_type: 'application/vnd.api+json'
    end
  end
end
