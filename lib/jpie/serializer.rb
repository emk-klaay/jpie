# frozen_string_literal: true

module JPie
  class Serializer
    attr_reader :resource_class, :options

    def initialize(resource_class, options = {})
      @resource_class = resource_class
      @options = options
    end

    def serialize(objects, context = {})
      return { data: nil } if objects.nil?

      resources = Array(objects).filter_map { |obj| obj ? resource_class.new(obj, context) : nil }

      if objects.is_a?(Array) || objects.respond_to?(:each)
        serialize_collection(resources)
      else
        resources.first ? serialize_single(resources.first) : { data: nil }
      end
    end

    private

    def serialize_single(resource)
      {
        data: serialize_resource_data(resource)
      }
    end

    def serialize_collection(resources)
      {
        data: resources.map { serialize_resource_data(it) }
      }
    end

    def serialize_resource_data(resource)
      data = {
        id: resource.id.to_s,
        type: format_key(resource.type),
        attributes: serialize_attributes(resource)
      }

      data.compact
    end

    def serialize_attributes(resource)
      attributes = resource.attributes_hash
      return {} if attributes.empty?

      attributes.transform_keys { format_key(it) }
                .transform_values { serialize_value(it) }
    end

    def serialize_value(value)
      case value
      when Time, DateTime, Date, ActiveSupport::TimeWithZone
        value.iso8601
      else
        value
      end
    end

    def format_key(key)
      case JPie.configuration.json_key_format
      when :dasherized
        key.to_s.dasherize
      when :underscored
        key.to_s.underscore
      when :camelized
        key.to_s.camelize(:lower)
      else
        key.to_s
      end
    end
  end
end
