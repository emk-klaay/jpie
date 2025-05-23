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
      result[:included] = included_data
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
      processor = IncludeProcessor.new(self, context)
      processor.process(resources, includes)
    end

    def parse_nested_includes(includes)
      result = {}

      includes.each do |include_path|
        parts = include_path.split('.')
        top_level = parts.first
        nested_path = parts[1..].join('.') if parts.length > 1

        result[top_level] ||= []
        result[top_level] << nested_path if nested_path.present?
      end

      result
    end

    # Helper class to manage include processing state and reduce parameter passing
    class IncludeProcessor
      attr_reader :serializer, :context, :included, :processed_includes

      def initialize(serializer, context)
        @serializer = serializer
        @context = context
        @included = []
        @processed_includes = {}
      end

      def process(resources, includes)
        parsed_includes = serializer.send(:parse_nested_includes, includes)
        parsed_includes.each do |include_name, nested_includes|
          process_single_include(include_name, nested_includes, resources)
        end
        included
      end

      private

      def process_single_include(include_name, nested_includes, resources)
        include_sym = include_name.to_sym
        relationship_options = serializer.resource_class._relationships[include_sym]
        return unless relationship_options

        resources.each do |resource|
          process_resource_relationships(resource, include_sym, relationship_options, nested_includes)
        end
      end

      def process_resource_relationships(resource, include_sym, relationship_options, nested_includes)
        related_objects = resource.public_send(include_sym)
        return unless related_objects

        Array(related_objects).each do |related_object|
          process_related_object(related_object, relationship_options, nested_includes)
        end
      end

      def process_related_object(related_object, relationship_options, nested_includes)
        related_resource_class = serializer.send(:determine_resource_class, related_object, relationship_options)
        return unless related_resource_class

        related_resource = related_resource_class.new(related_object, context)
        resource_data = serializer.send(:serialize_resource_data, related_resource)

        add_to_included_if_unique(resource_data)
        process_nested_includes_for_resource(related_resource_class, related_resource, nested_includes)
      end

      def add_to_included_if_unique(resource_data)
        key = [resource_data[:type], resource_data[:id]]
        return if processed_includes[key]

        processed_includes[key] = true
        included << resource_data
      end

      def process_nested_includes_for_resource(related_resource_class, related_resource, nested_includes)
        return unless nested_includes.any?

        nested_serializer = JPie::Serializer.new(related_resource_class)
        nested_included = nested_serializer.send(:collect_included_data, [related_resource], nested_includes, context)

        nested_included.each do |nested_item|
          add_to_included_if_unique(nested_item)
        end
      end
    end

    def determine_resource_class(object, relationship_options)
      # First try the explicitly specified resource class
      if relationship_options[:resource]
        begin
          return relationship_options[:resource].constantize
        rescue NameError
          # If the resource class doesn't exist, it might be a polymorphic relationship
          # Fall through to polymorphic detection
        end
      end

      # For polymorphic relationships, determine resource class from object class
      if object&.class
        resource_class_name = "#{object.class.name}Resource"
        begin
          return resource_class_name.constantize
        rescue NameError
          # Resource class doesn't exist for this object type
          return nil
        end
      end

      nil
    end
  end
end
