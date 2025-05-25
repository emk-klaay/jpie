# frozen_string_literal: true

module JPie
  module Controller
    module JsonApiValidation
      extend ActiveSupport::Concern

      private

      # Validate that the request is JSON:API compliant
      def validate_json_api_request
        validate_content_type if request.post? || request.patch? || request.put?
        validate_json_api_structure if request.post? || request.patch? || request.put?
      end

      # Validate Content-Type header for write operations
      def validate_content_type
        # Only validate content type for write operations
        return unless request.post? || request.patch? || request.put?

        content_type = request.content_type
        return if content_type&.include?('application/vnd.api+json')

        raise JPie::Errors::InvalidJsonApiRequestError.new(
          detail: 'Content-Type must be application/vnd.api+json for JSON:API requests'
        )
      end

      # Validate basic JSON:API request structure
      def validate_json_api_structure
        request_body = read_request_body
        return if request_body.blank?

        parsed_body = parse_json_body(request_body)
        validate_top_level_structure(parsed_body)
        validate_data_structure(parsed_body['data'])
      end

      def read_request_body
        request_body = request.body.read
        request.body.rewind # Reset for later reading
        request_body
      end

      def parse_json_body(request_body)
        JSON.parse(request_body)
      rescue JSON::ParserError => e
        raise JPie::Errors::InvalidJsonApiRequestError.new(
          detail: "Invalid JSON: #{e.message}"
        )
      end

      def validate_top_level_structure(parsed_body)
        return if parsed_body.is_a?(Hash) && parsed_body.key?('data')

        raise JPie::Errors::InvalidJsonApiRequestError.new(
          detail: 'JSON:API request must have a top-level "data" member'
        )
      end

      # Validate the structure of the data member
      def validate_data_structure(data)
        if data.is_a?(Array)
          data.each { |item| validate_resource_object(item) }
        elsif data.is_a?(Hash)
          validate_resource_object(data)
        elsif !data.nil?
          raise JPie::Errors::InvalidJsonApiRequestError.new(
            detail: 'Data member must be an object, array, or null'
          )
        end
      end

      # Validate individual resource object structure
      def validate_resource_object(resource)
        unless resource.is_a?(Hash)
          raise JPie::Errors::InvalidJsonApiRequestError.new(
            detail: 'Resource objects must be JSON objects'
          )
        end

        unless resource.key?('type')
          raise JPie::Errors::InvalidJsonApiRequestError.new(
            detail: 'Resource objects must have a "type" member'
          )
        end

        # ID is required for updates but not for creates
        return unless request.patch? || request.put?
        return if resource.key?('id')

        raise JPie::Errors::InvalidJsonApiRequestError.new(
          detail: 'Resource objects must have an "id" member for updates'
        )
      end

      # Validate include parameters against supported includes
      def validate_include_params
        return if params[:include].blank?

        include_paths = params[:include].to_s.split(',').map(&:strip)
        supported_includes = resource_class.supported_includes

        include_paths.each do |include_path|
          next if include_path.blank?

          validate_include_path(include_path, supported_includes)
        end
      end

      # Validate a single include path
      def validate_include_path(include_path, supported_includes)
        path_parts = include_path.split('.')
        current_level = supported_includes

        path_parts.each_with_index do |part, index|
          validate_include_part(part, current_level, path_parts, index)
          current_level = move_to_next_include_level(part, current_level)
        end
      end

      def validate_include_part(part, current_level, path_parts, index)
        return if include_part_supported?(part, current_level)

        current_path = path_parts[0..index].join('.')
        available_at_level = extract_available_includes(current_level)

        raise JPie::Errors::UnsupportedIncludeError.new(
          include_path: current_path,
          supported_includes: available_at_level.map(&:to_s)
        )
      end

      def include_part_supported?(part, current_level)
        current_level.include?(part.to_sym) || current_level.include?(part)
      end

      def extract_available_includes(current_level)
        current_level.is_a?(Hash) ? current_level.keys : current_level
      end

      def move_to_next_include_level(part, current_level)
        return current_level unless current_level.is_a?(Hash)

        current_level[part.to_sym] if current_level[part.to_sym].is_a?(Hash)
        current_level[part] if current_level[part].is_a?(Hash)
        current_level
      end

      # Validate sort parameters against supported fields
      def validate_sort_params
        return if params[:sort].blank?

        sort_fields = params[:sort].to_s.split(',').map(&:strip)
        supported_fields = resource_class.supported_sort_fields

        sort_fields.each do |sort_field|
          next if sort_field.blank?

          validate_sort_field(sort_field, supported_fields)
        end
      end

      # Validate a single sort field
      def validate_sort_field(sort_field, supported_fields)
        # Remove leading minus for descending sort
        field_name = sort_field.start_with?('-') ? sort_field[1..] : sort_field

        # Validate field name format
        unless field_name.match?(/\A[a-zA-Z][a-zA-Z0-9_]*\z/)
          raise JPie::Errors::InvalidSortParameterError.new(
            detail: "Invalid sort field format: '#{sort_field}'. " \
                    'Field names must start with a letter and contain only letters, numbers, and underscores'
          )
        end

        return if supported_fields.include?(field_name.to_sym) || supported_fields.include?(field_name)

        raise JPie::Errors::UnsupportedSortFieldError.new(
          sort_field: field_name,
          supported_fields: supported_fields.map(&:to_s)
        )
      end

      # Validate all JSON:API request aspects
      def validate_json_api_compliance
        validate_json_api_request
        validate_include_params
        validate_sort_params
      end
    end
  end
end
