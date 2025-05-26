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
        validate_relationship_type
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
        unless resource_identifier.is_a?(Hash) &&
               resource_identifier.key?('type') &&
               resource_identifier.key?('id')
          raise JPie::Errors::BadRequestError.new(
            detail: 'Resource identifier objects must have "type" and "id" members'
          )
        end

        type = resource_identifier['type']
        id = resource_identifier['id']

        unless type.is_a?(String) && id.is_a?(String)
          raise JPie::Errors::BadRequestError.new(
            detail: 'Resource identifier object members must be strings'
          )
        end

        if type.empty? || id.empty?
          raise JPie::Errors::BadRequestError.new(
            detail: 'Resource identifier object members cannot be empty strings'
          )
        end
      end

      def validate_relationship_type
        validate_relationship_exists
        data = parse_relationship_data

        if relationship_is_to_many?
          validate_to_many_relationship_data(data)
        else
          validate_to_one_relationship_data(data)
        end
      end

      def validate_to_many_relationship_data(data)
        if data.nil?
          raise JPie::Errors::BadRequestError.new(
            detail: 'Cannot set a to-many relationship to null'
          )
        end

        unless data.is_a?(Array)
          raise JPie::Errors::BadRequestError.new(
            detail: 'The value of data must be an array for to-many relationships'
          )
        end

        data.each { |identifier| validate_resource_identifier(identifier) }
      end

      def validate_to_one_relationship_data(data)
        unless data.nil? || data.is_a?(Hash)
          raise JPie::Errors::BadRequestError.new(
            detail: 'The value of data must be a single resource identifier object or null for to-one relationships'
          )
        end

        validate_resource_identifier(data) if data
      end

      def relationship_is_to_many?
        return false unless relationship_config

        relationship_config[:type] == :has_many
      end
    end
  end
end
