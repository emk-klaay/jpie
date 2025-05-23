# frozen_string_literal: true

module JPie
  class Resource
    include ActiveSupport::Configurable

    class_attribute :_type, :_attributes, :_model_class, :_relationships, :_meta_attributes, :_sortable_fields
    self._attributes = []
    self._relationships = {}
    self._meta_attributes = []
    self._sortable_fields = {}

    class << self
      def inherited(subclass)
        super
        subclass._attributes = _attributes.dup
        subclass._relationships = _relationships.dup
        subclass._meta_attributes = _meta_attributes.dup
        subclass._sortable_fields = _sortable_fields.dup
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

      # Define a sortable field with optional custom sorting logic
      # Example:
      #   sortable_by :name
      #   sortable_by :created_at, :created_at_desc
      #   sortable_by :popularity do |direction|
      #     if direction == :asc
      #       model.order(:likes_count)
      #     else
      #       model.order(likes_count: :desc)
      #     end
      #   end
      def sortable_by(field, column = nil, &block)
        field = field.to_sym
        _sortable_fields[field] = block || column || field
      end

      # Apply sorting to a query based on sort parameters
      # sort_fields: array of sort field strings (e.g., ['name', '-created_at'])
      def sort(query, sort_fields)
        return query if sort_fields.blank?

        sort_fields.each do |sort_field|
          # Parse direction (- prefix means descending)
          if sort_field.start_with?('-')
            field = sort_field[1..].to_sym
            direction = :desc
          else
            field = sort_field.to_sym
            direction = :asc
          end

          # Check if field is sortable
          unless sortable_field?(field)
            raise JPie::Errors::BadRequestError.new(
              detail: "Invalid sort field: #{field}. Sortable fields are: #{sortable_fields.join(', ')}"
            )
          end

          # Apply sorting
          query = apply_sort(query, field, direction)
        end

        query
      end

      # Get list of all sortable fields (attributes + explicitly defined sortable fields)
      def sortable_fields
        (_attributes + _sortable_fields.keys).uniq.map(&:to_s)
      end

      # Check if a field is sortable
      def sortable_field?(field)
        field = field.to_sym
        _attributes.include?(field) || _sortable_fields.key?(field)
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

      # Apply a single sort to the query
      def apply_sort(query, field, direction)
        sortable_config = _sortable_fields[field]

        if sortable_config.is_a?(Proc)
          # Custom sorting block
          instance_exec(query, direction, &sortable_config)
        elsif sortable_config.is_a?(Symbol)
          # Custom column name
          query.order(sortable_config => direction)
        else
          # Default sorting by attribute name
          query.order(field => direction)
        end
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
