# frozen_string_literal: true

module JPie
  module Controller
    module ErrorHandling
      module HandlerSetup
        extend ActiveSupport::Concern

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
            setup_core_error_handlers
            setup_activerecord_handlers
            setup_json_api_compliance_handlers
          end

          def setup_core_error_handlers
            return if rescue_handler?(JPie::Errors::Error)

            rescue_from JPie::Errors::Error, with: :handle_jpie_error
          end

          def setup_activerecord_handlers
            setup_not_found_handler
            setup_invalid_record_handler
          end

          def setup_not_found_handler
            return if rescue_handler?(ActiveRecord::RecordNotFound)

            rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
          end

          def setup_invalid_record_handler
            return if rescue_handler?(ActiveRecord::RecordInvalid)

            rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
          end

          def setup_json_api_compliance_handlers
            setup_json_api_request_handler
            setup_include_handlers
            setup_sort_handlers
          end

          def setup_json_api_request_handler
            return if rescue_handler?(JPie::Errors::InvalidJsonApiRequestError)

            rescue_from JPie::Errors::InvalidJsonApiRequestError, with: :handle_invalid_json_api_request
          end

          def setup_include_handlers
            setup_unsupported_include_handler
            setup_invalid_include_handler
          end

          def setup_unsupported_include_handler
            return if rescue_handler?(JPie::Errors::UnsupportedIncludeError)

            rescue_from JPie::Errors::UnsupportedIncludeError, with: :handle_unsupported_include
          end

          def setup_invalid_include_handler
            return if rescue_handler?(JPie::Errors::InvalidIncludeParameterError)

            rescue_from JPie::Errors::InvalidIncludeParameterError, with: :handle_invalid_include_parameter
          end

          def setup_sort_handlers
            setup_unsupported_sort_handler
            setup_invalid_sort_handler
          end

          def setup_unsupported_sort_handler
            return if rescue_handler?(JPie::Errors::UnsupportedSortFieldError)

            rescue_from JPie::Errors::UnsupportedSortFieldError, with: :handle_unsupported_sort_field
          end

          def setup_invalid_sort_handler
            return if rescue_handler?(JPie::Errors::InvalidSortParameterError)

            rescue_from JPie::Errors::InvalidSortParameterError, with: :handle_invalid_sort_parameter
          end

          def remove_jpie_handlers
            # This is a placeholder - Rails doesn't provide an easy way to remove specific handlers
            # In practice, applications should use the disable_jpie_error_handlers before including
          end
        end
      end
    end
  end
end
