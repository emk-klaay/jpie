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
        def attribute(name, options = {})
          name = name.to_sym
          _attributes << name unless _attributes.include?(name)

          define_method(name) do
            if options[:block]
              instance_exec(&options[:block])
            else
              attr_name = options[:attr] || name
              @object.public_send(attr_name)
            end
          end
        end

        def attributes(*names)
          names.each { attribute(it) }
        end

        def meta_attribute(name, options = {})
          name = name.to_sym
          _meta_attributes << name unless _meta_attributes.include?(name)

          define_method(name) do
            if options[:block]
              instance_exec(&options[:block])
            else
              attr_name = options[:attr] || name
              @object.public_send(attr_name)
            end
          end
        end

        def meta_attributes(*names)
          names.each { meta_attribute(it) }
        end

        def relationship(name, options = {})
          name = name.to_sym
          _relationships[name] = options

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
