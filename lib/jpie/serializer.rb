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

      meta_data = serialize_meta(resource)
      data[:meta] = meta_data if meta_data.any?

      data.compact
    end

    def serialize_attributes(resource)
      attributes = resource.attributes_hash
      return {} if attributes.empty?

      attributes.transform_keys { it.to_s.underscore }
                .transform_values { serialize_value(it) }
    end

    def serialize_meta(resource)
      meta_attributes = resource.meta_hash
      return {} if meta_attributes.empty?

      meta_attributes.transform_keys { it.to_s.underscore }
                     .transform_values { serialize_value(it) }
    end

    def serialize_value(value)
      value.respond_to?(:iso8601) ? value.iso8601 : value
    end

    def collect_included_data(resources, includes, context)
      included = []
      processed_includes = {}

      # Parse nested includes - convert "user.comments" to structured format
      parsed_includes = parse_nested_includes(includes)

      # Process each top-level include
      parsed_includes.each do |include_name, nested_includes|
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
            resource_data = serialize_resource_data(related_resource)
            
            # Use a unique key to avoid duplicates
            key = [resource_data[:type], resource_data[:id]]
            next if processed_includes[key]
            
            processed_includes[key] = true
            included << resource_data

            # Process nested includes recursively
            if nested_includes.any?
              nested_serializer = JPie::Serializer.new(related_resource_class)
              nested_included = nested_serializer.send(:collect_included_data, [related_resource], nested_includes, context)
              
              nested_included.each do |nested_item|
                nested_key = [nested_item[:type], nested_item[:id]]
                next if processed_includes[nested_key]
                
                processed_includes[nested_key] = true
                included << nested_item
              end
            end
          end
        end
      end

      included
    end

    def parse_nested_includes(includes)
      result = {}
      
      includes.each do |include_path|
        parts = include_path.split('.')
        top_level = parts.first
        nested_path = parts[1..-1].join('.') if parts.length > 1
        
        result[top_level] ||= []
        result[top_level] << nested_path if nested_path && !nested_path.empty?
      end
      
      result
    end
  end
end
