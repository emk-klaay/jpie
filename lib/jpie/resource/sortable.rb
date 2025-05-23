# frozen_string_literal: true

module JPie
  class Resource
    module Sortable
      extend ActiveSupport::Concern

      included do
        class_attribute :_sortable_fields
        self._sortable_fields = {}
      end

      class_methods do
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
    end
  end
end
