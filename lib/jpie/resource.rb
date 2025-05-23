# frozen_string_literal: true

module JPie
  class Resource
    include ActiveSupport::Configurable

    class_attribute :_type, :_attributes, :_model_class
    self._attributes = []

    class << self
      def inherited(subclass)
        super
        subclass._attributes = _attributes.dup
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

      private

      def infer_model_class
        name.chomp('Resource').constantize
      rescue NameError
        nil
      end

      def infer_type_name
        model&.model_name&.plural || name.chomp('Resource').underscore.pluralize
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
