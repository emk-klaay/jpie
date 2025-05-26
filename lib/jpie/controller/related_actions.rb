# frozen_string_literal: true

module JPie
  module Controller
    module RelatedActions
      extend ActiveSupport::Concern

      # GET /resources/:id/:relationship_name
      # Returns the related resources themselves (not just linkage)
      def related_show
        validate_relationship_exists
        validate_include_params
        resource = find_resource
        related_resources = get_related_resources(resource)
        render_jsonapi(related_resources)
      end

      private

      def validate_relationship_exists
        relationship_name = params[:relationship_name]
        return unless relationship_name # Skip validation if no relationship_name param

        return if resource_class._relationships.key?(relationship_name.to_sym)

        raise JPie::Errors::NotFoundError.new(
          detail: "Relationship '#{relationship_name}' does not exist for #{resource_class.name}"
        )
      end

      def find_resource
        resource_class.scope(context).find(params[:id])
      end

      def relationship_name
        @relationship_name ||= params[:relationship_name].to_sym
      end

      def get_related_resources(resource)
        relationship_method = relationship_name
        resource.send(relationship_method)
      end
    end
  end
end
