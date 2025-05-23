# frozen_string_literal: true

module JPie
  class Deserializer
    attr_reader :resource_class, :options

    def initialize(resource_class, options = {})
      @resource_class = resource_class
      @options = options
    end

    def deserialize(json_data, context = {})
      data = json_data.is_a?(String) ? JSON.parse(json_data) : json_data

      validate_json_api_structure!(data)

      if data['data'].is_a?(Array)
        deserialize_collection(data['data'], context)
      else
        deserialize_single(data['data'], context)
      end
    rescue JSON::ParserError => e
      raise Errors::BadRequestError.new(detail: "Invalid JSON: #{e.message}")
    end

    private

    def deserialize_single(resource_data, context)
      validate_resource_data!(resource_data)
      extract_attributes(resource_data, context)
    end

    def deserialize_collection(resources_data, context)
      resources_data.map { deserialize_single(it, context) }
    end

    def extract_attributes(resource_data, _context)
      attributes = resource_data['attributes'] || {}
      type = resource_data['type']
      id = resource_data['id']

      validate_type!(type) if type

      # Transform keys back to model format (underscore is already the model format)
      model_attributes = attributes.transform_keys { it.to_s.underscore }

      # Only include attributes that are defined in the resource class
      allowed_attributes = resource_class._attributes.map(&:to_s)
      filtered_attributes = model_attributes.slice(*allowed_attributes)

      result = filtered_attributes.transform_values { deserialize_value(it) }
      result['id'] = id if id

      result.with_indifferent_access
    end

    def deserialize_value(value)
      case value
      when String
        # Only try to parse as datetime if it looks like an ISO8601 string
        if value.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
          begin
            Time.parse(value)
          rescue ArgumentError, TypeError
            value
          end
        else
          value
        end
      else
        value
      end
    end

    def validate_json_api_structure!(data)
      return if data.is_a?(Hash) && data.key?('data')

      raise Errors::BadRequestError.new(detail: 'Invalid JSON:API structure. Missing "data" key.')
    end

    def validate_resource_data!(resource_data)
      raise Errors::BadRequestError.new(detail: 'Invalid resource data structure.') unless resource_data.is_a?(Hash)

      return if resource_data.key?('type')

      raise Errors::BadRequestError.new(detail: 'Resource data must include "type".')
    end

    def validate_type!(type)
      expected_type = resource_class.type
      return if type == expected_type

      raise Errors::BadRequestError.new(
        detail: "Expected type '#{expected_type}', got '#{type}'"
      )
    end
  end
end
