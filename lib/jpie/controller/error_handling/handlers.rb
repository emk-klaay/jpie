# frozen_string_literal: true

module JPie
  module Controller
    module ErrorHandling
      module Handlers
        extend ActiveSupport::Concern

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

        # Handle JSON:API compliance errors
        def handle_invalid_json_api_request(error)
          render_json_api_error(
            status: error.status,
            title: error.title || 'Invalid JSON:API Request',
            detail: error.detail
          )
        end

        def handle_unsupported_include(error)
          render_json_api_error(
            status: error.status,
            title: error.title || 'Unsupported Include',
            detail: error.detail
          )
        end

        def handle_unsupported_sort_field(error)
          render_json_api_error(
            status: error.status,
            title: error.title || 'Unsupported Sort Field',
            detail: error.detail
          )
        end

        def handle_invalid_sort_parameter(error)
          render_json_api_error(
            status: error.status,
            title: error.title || 'Invalid Sort Parameter',
            detail: error.detail
          )
        end

        def handle_invalid_include_parameter(error)
          render_json_api_error(
            status: error.status,
            title: error.title || 'Invalid Include Parameter',
            detail: error.detail
          )
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
end
