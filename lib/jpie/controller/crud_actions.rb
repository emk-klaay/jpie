# frozen_string_literal: true

module JPie
  module Controller
    module CrudActions
      extend ActiveSupport::Concern

      class_methods do
        def jsonapi_resource(resource_class)
          setup_jsonapi_resource(resource_class)
        end

        private

        def setup_jsonapi_resource(resource_class)
          define_method :resource_class do
            resource_class
          end

          # Define automatic CRUD methods
          define_automatic_crud_methods(resource_class)
        end

        def define_automatic_crud_methods(resource_class)
          define_index_method(resource_class)
          define_show_method(resource_class)
          define_create_method(resource_class)
          define_update_method(resource_class)
          define_destroy_method(resource_class)
        end

        def define_index_method(resource_class)
          define_method :index do
            resources = resource_class.scope(context)
            sort_fields = parse_sort_params
            resources = resource_class.sort(resources, sort_fields) if sort_fields.any?
            render_jsonapi_resources(resources)
          end
        end

        def define_show_method(resource_class)
          define_method :show do
            resource = resource_class.scope(context).find(params[:id])
            render_jsonapi_resource(resource)
          end
        end

        def define_create_method(resource_class)
          define_method :create do
            attributes = deserialize_params
            resource = resource_class.model.create!(attributes)
            render_jsonapi_resource(resource, status: :created)
          end
        end

        def define_update_method(resource_class)
          define_method :update do
            resource = resource_class.scope(context).find(params[:id])
            attributes = deserialize_params
            resource.update!(attributes)
            render_jsonapi_resource(resource)
          end
        end

        def define_destroy_method(resource_class)
          define_method :destroy do
            resource = resource_class.scope(context).find(params[:id])
            resource.destroy!
            head :no_content
          end
        end
      end

      # These methods can still be called manually or used to override defaults
      def index
        resources = resource_class.scope(context)
        sort_fields = parse_sort_params
        resources = resource_class.sort(resources, sort_fields) if sort_fields.any?
        render_jsonapi_resources(resources)
      end

      def show
        resource = resource_class.scope(context).find(params[:id])
        render_jsonapi_resource(resource)
      end

      def create
        attributes = deserialize_params
        resource = model_class.create!(attributes)
        render_jsonapi_resource(resource, status: :created)
      end

      def update
        resource = resource_class.scope(context).find(params[:id])
        attributes = deserialize_params
        resource.update!(attributes)
        render_jsonapi_resource(resource)
      end

      def destroy
        resource = resource_class.scope(context).find(params[:id])
        resource.destroy!
        head :no_content
      end
    end
  end
end
