# frozen_string_literal: true

module JPie
  module Controller
    module ErrorHandling
      extend ActiveSupport::Concern

      included do
        # Use class_attribute to allow easy overriding
        class_attribute :jpie_error_handlers_enabled, default: true

        # Set up default handlers unless explicitly disabled
        setup_jpie_error_handlers if jpie_error_handlers_enabled
      end

      class_methods do
        # Allow applications to easily disable all JPie error handlers
        def disable_jpie_error_handlers
          self.jpie_error_handlers_enabled = false
          # Remove any already-added handlers
          remove_jpie_handlers
        end

        # Allow applications to enable specific handlers
        def enable_jpie_error_handler(error_class, method_name = nil)
          method_name ||= :"handle_#{error_class.name.demodulize.underscore}"
          rescue_from error_class, with: method_name
        end

        # Check for application-defined error handlers
        def rescue_handler?(exception_class)
          # Use Rails' rescue_handlers method to check for existing handlers
          return false unless respond_to?(:rescue_handlers, true)

          begin
            rescue_handlers.any? { |handler| handler.first == exception_class.name }
          rescue NoMethodError
            false
          end
        end

        private

        def setup_jpie_error_handlers
          setup_jpie_specific_handlers
        end

        def setup_jpie_specific_handlers
          # Only add handlers if they don't already exist
          rescue_from JPie::Errors::Error, with: :handle_jpie_error unless rescue_handler?(JPie::Errors::Error)
          unless rescue_handler?(ActiveRecord::RecordNotFound)
            rescue_from ActiveRecord::RecordNotFound,
                        with: :handle_record_not_found
          end
          return if rescue_handler?(ActiveRecord::RecordInvalid)

          rescue_from ActiveRecord::RecordInvalid,
                      with: :handle_record_invalid
        end

        def remove_jpie_handlers
          # This is a placeholder - Rails doesn't provide an easy way to remove specific handlers
          # In practice, applications should use the disable_jpie_error_handlers before including
        end
      end

      private

      # Handle JPie-specific errors
      def handle_jpie_error(error)
        render_json_api_error(
          status: error.status,
          title: error.title,
          detail: error.detail
        )
      end

      # Handle ActiveRecord::RecordNotFound
      def handle_record_not_found(error)
        render_json_api_error(
          status: 404,
          title: 'Not Found',
          detail: error.message
        )
      end

      # Handle ActiveRecord::RecordInvalid
      def handle_record_invalid(error)
        errors = error.record.errors.full_messages.map do |message|
          {
            status: '422',
            title: 'Validation Error',
            detail: message
          }
        end

        render json: { errors: errors }, status: :unprocessable_content
      end

      # Render a single JSON:API error
      def render_json_api_error(status:, title:, detail:)
        render json: {
          errors: [{
            status: status.to_s,
            title: title,
            detail: detail
          }]
        }, status: status
      end

      # Backward compatibility aliases
      alias jpie_handle_error handle_jpie_error
      alias jpie_handle_not_found handle_record_not_found
      alias jpie_handle_invalid handle_record_invalid

      # Legacy method name aliases
      alias render_jpie_error handle_jpie_error
      alias render_jpie_not_found_error handle_record_not_found
      alias render_jpie_validation_error handle_record_invalid
      alias render_jsonapi_error handle_jpie_error
      alias render_not_found_error handle_record_not_found
      alias render_validation_error handle_record_invalid
    end
  end
end
