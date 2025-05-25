# frozen_string_literal: true

require_relative 'resource/attributable'
require_relative 'resource/inferrable'
require_relative 'resource/sortable'
require_relative 'errors'

module JPie
  class Resource
    include ActiveSupport::Configurable
    include Attributable
    include Inferrable
    include Sortable

    class << self
      def inherited(subclass)
        super
        subclass._attributes = _attributes.dup
        subclass._relationships = _relationships.dup
        subclass._meta_attributes = _meta_attributes.dup
        subclass._sortable_fields = _sortable_fields.dup
      end

      # Default scope method that returns all records
      # Override this in your resource classes to provide authorization scoping
      # Example:
      #   def self.scope(context)
      #     current_user = context[:current_user]
      #     return model.none unless current_user
      #
      #     if current_user.admin?
      #       model.all
      #     else
      #       model.where(user: current_user)
      #     end
      #   end
      def scope(_context = {})
        model.all
      end

      # Return supported include paths for validation
      # Override this method to customize supported includes
      def supported_includes
        # Return relationship names as supported includes by default
        _relationships.keys.map(&:to_s)

        # Convert to nested hash format for complex includes
        # For simple includes, return array format
      end

      # Return supported sort fields for validation
      # Override this method to customize supported sort fields
      def supported_sort_fields
        # Return all attributes and sortable fields as supported sort fields by default
        fields = (_attributes + _sortable_fields.keys).uniq.map(&:to_s)

        # Add common model timestamp fields if the model supports them
        if model.respond_to?(:column_names)
          fields << 'created_at' if model.column_names.include?('created_at') && fields.exclude?('created_at')

          fields << 'updated_at' if model.column_names.include?('updated_at') && fields.exclude?('updated_at')
        end

        fields
      end
    end

    attr_reader :object, :context

    def initialize(object, context = {})
      @object = object
      @context = context
    end

    delegate :id, to: :@object

    delegate :type, to: :class

    def attributes_hash
      self.class._attributes.index_with do
        send(it)
      end
    end

    def meta_hash
      # Start with meta attributes from the macro
      base_meta = self.class._meta_attributes.index_with do
        send(it)
      end

      # Check if the resource defines a custom meta method
      if respond_to?(:meta, true) && method(:meta).owner != JPie::Resource
        custom_meta = meta

        # Validate that meta method returns a hash
        unless custom_meta.is_a?(Hash)
          raise JPie::Errors::ResourceError.new(
            detail: "meta method must return a Hash, got #{custom_meta.class}"
          )
        end

        # Merge custom meta with base meta (custom meta takes precedence)
        base_meta.merge(custom_meta)
      else
        base_meta
      end
    end

    protected

    # Default meta method that returns the meta attributes
    # This can be overridden in subclasses
    def meta
      self.class._meta_attributes.index_with do
        send(it)
      end
    end

    private

    def method_missing(method_name, *, &)
      if @object.respond_to?(method_name)
        @object.public_send(method_name, *, &)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @object.respond_to?(method_name, include_private) || super
    end
  end
end
