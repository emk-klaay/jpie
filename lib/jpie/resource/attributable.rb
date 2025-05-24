# frozen_string_literal: true

module JPie
  class Resource
    module Attributable
      extend ActiveSupport::Concern

      included do
        class_attribute :_attributes, :_relationships, :_meta_attributes
        self._attributes = []
        self._relationships = {}
        self._meta_attributes = []
      end

      class_methods do
        def attribute(name, options = {}, &)
          name = name.to_sym
          _attributes << name unless _attributes.include?(name)
          define_attribute_method(name, options, &)
        end

        def attributes(*names)
          names.each { attribute(it) }
        end

        def meta_attribute(name, options = {}, &)
          name = name.to_sym
          _meta_attributes << name unless _meta_attributes.include?(name)
          define_attribute_method(name, options, &)
        end

        def meta_attributes(*names)
          names.each { meta_attribute(it) }
        end

        # More concise aliases for modern Rails style
        alias_method :meta, :meta_attribute
        alias_method :metas, :meta_attributes

        def relationship(name, options = {})
          name = name.to_sym
          _relationships[name] = options

          # Check if method is already defined (public or private) to allow custom implementations
          return if method_defined?(name) || private_method_defined?(name)

          define_method(name) do
            attr_name = options[:attr] || name
            @object.public_send(attr_name)
          end
        end

        def has_many(name, options = {})
          name = name.to_sym
          resource_class_name = options[:resource] || infer_resource_class_name(name)
          relationship(name, { resource: resource_class_name }.merge(options))
        end

        def has_one(name, options = {})
          name = name.to_sym
          resource_class_name = options[:resource] || infer_resource_class_name(name)
          relationship(name, { resource: resource_class_name }.merge(options))
        end

        private

        def define_attribute_method(name, options, &)
          # If a block is provided, use it (existing behavior)
          if block_given?
            define_method(name) do
              instance_exec(&)
            end
          # If options[:block] is provided, use it (existing behavior)
          elsif options[:block]
            define_method(name) do
              instance_exec(&options[:block])
            end
          # If method is not already defined on the resource (public or private), define the default implementation
          elsif !method_defined?(name) && !private_method_defined?(name)
            define_method(name) do
              attr_name = options[:attr] || name
              @object.public_send(attr_name)
            end
          end
          # If method is already defined, don't override it - let the custom method handle it
        end

        def infer_resource_class_name(relationship_name)
          # Convert relationship name to resource class name
          # :posts -> "PostResource"
          # :user -> "UserResource"
          singularized_name = relationship_name.to_s.singularize
          "#{singularized_name.camelize}Resource"
        end
      end
    end
  end
end
