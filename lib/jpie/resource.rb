# frozen_string_literal: true

module JPie
  class Resource
    include ActiveSupport::Configurable

    class_attribute :_type, :_attributes, :_model_class, :_relationships, :_meta_attributes
    self._attributes = []
    self._relationships = {}
    self._meta_attributes = []

    class << self
      def inherited(subclass)
        super
        subclass._attributes = _attributes.dup
        subclass._relationships = _relationships.dup
        subclass._meta_attributes = _meta_attributes.dup
      end

      def model(model_class = nil)
        if model_class
          self._model_class = model_class
        else
          _model_class || infer_model_class
        end
      end

      def type(type_name = nil)
        if type_name
          self._type = type_name.to_s
        else
          _type || infer_type_name
        end
      end

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

      private

      def infer_model_class
        name.chomp('Resource').constantize
      rescue NameError
        nil
      end

      def infer_type_name
        model&.model_name&.plural || name.chomp('Resource').underscore.pluralize
      end

      def infer_resource_class_name(relationship_name)
        # Convert relationship name to resource class name
        # :posts -> "PostResource"
        # :user -> "UserResource"
        singularized_name = relationship_name.to_s.singularize
        "#{singularized_name.camelize}Resource"
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
        public_send(it)
      end
    end

    def meta_hash
      self.class._meta_attributes.index_with do
        public_send(it)
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
