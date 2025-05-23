# frozen_string_literal: true

module JPie
  class Serializer
    attr_reader :resource_class, :options

    def initialize(resource_class, options = {})
      @resource_class = resource_class
      @options = options
    end

    def serialize(objects, context = {}, includes: [])
      return { data: nil } if objects.nil?

      resources = build_resources(objects, context)
      result = serialize_data(objects, resources)
      add_included_data(result, resources, includes, context) if should_include_data?(includes, result)
      result
    end

    private

    def build_resources(objects, context)
      Array(objects).filter_map { |obj| obj ? resource_class.new(obj, context) : nil }
    end

    def serialize_data(objects, resources)
      if objects.is_a?(Array) || objects.respond_to?(:each)
        serialize_collection(resources)
      else
        resources.first ? serialize_single(resources.first) : { data: nil }
      end
    end

    def should_include_data?(includes, result)
      includes.any? && result[:data]
    end

    def add_included_data(result, resources, includes, context)
      included_data = collect_included_data(resources, includes, context)
      result[:included] = included_data if included_data.any?
    end

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
        type: resource.type,
        attributes: serialize_attributes(resource)
      }

      data.compact
    end

    def serialize_attributes(resource)
      attributes = resource.attributes_hash
      return {} if attributes.empty?

      attributes.transform_keys { it.to_s.underscore }
                .transform_values { serialize_value(it) }
    end

    def serialize_value(value)
      value.respond_to?(:iso8601) ? value.iso8601 : value
    end

    def collect_included_data(resources, includes, context)
      included = []

      includes.each do |include_name|
        include_sym = include_name.to_sym
        relationship_options = resource_class._relationships[include_sym]

        next unless relationship_options

        related_resource_class_name = relationship_options[:resource]
        related_resource_class = related_resource_class_name.constantize

        resources.each do |resource|
          related_objects = resource.public_send(include_sym)
          next unless related_objects

          related_objects = Array(related_objects)
          related_objects.each do |related_object|
            related_resource = related_resource_class.new(related_object, context)
            included << serialize_resource_data(related_resource)
          end
        end
      end

      included.uniq { |item| [item[:type], item[:id]] }
    end
  end
end
