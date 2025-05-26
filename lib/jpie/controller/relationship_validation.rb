# frozen_string_literal: true

module JPie
  module Controller
    module RelationshipValidation
      private

      def validate_relationship_exists
        relationship_name = params[:relationship_name]
        return unless relationship_name # Skip validation if no relationship_name param

        return if resource_class._relationships.key?(relationship_name.to_sym)

        raise JPie::Errors::NotFoundError.new(
          detail: "Relationship '#{relationship_name}' does not exist for #{resource_class.name}"
        )
      end

      def validate_relationship_update_request
        validate_content_type
        validate_request_body
      end

      def validate_content_type
        # Only validate content type for write operations
        return unless request.post? || request.patch? || request.put?

        content_type = request.content_type
        return if content_type&.include?('application/vnd.api+json')

        raise JPie::Errors::InvalidJsonApiRequestError.new(
          detail: 'Content-Type must be application/vnd.api+json for JSON:API requests'
        )
      end

      def validate_request_body
        body = request.body.read
        request.body.rewind

        raise JPie::Errors::BadRequestError.new(detail: 'Request body cannot be empty') if body.blank?

        JSON.parse(body)
      rescue JSON::ParserError => e
        raise JPie::Errors::BadRequestError.new(detail: "Invalid JSON: #{e.message}")
      end

      def validate_resource_identifier(resource_identifier)
        return if resource_identifier.is_a?(Hash) &&
                  resource_identifier.key?('type') &&
                  resource_identifier.key?('id')

        raise JPie::Errors::BadRequestError.new(
          detail: 'Resource identifier objects must have "type" and "id" members'
        )
      end
    end
  end
end
