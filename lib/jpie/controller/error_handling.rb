# frozen_string_literal: true

module JPie
  module Controller
    module ErrorHandling
      extend ActiveSupport::Concern

      included do
        rescue_from JPie::Errors::Error, with: :render_jsonapi_error

        if defined?(ActiveRecord)
          rescue_from ActiveRecord::RecordNotFound, with: :render_not_found_error
          rescue_from ActiveRecord::RecordInvalid, with: :render_validation_error
        end
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
    end
  end
end
