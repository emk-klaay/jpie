# frozen_string_literal: true

require_relative 'resource/attributable'
require_relative 'resource/inferrable'
require_relative 'resource/sortable'

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
