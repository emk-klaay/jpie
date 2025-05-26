# frozen_string_literal: true

require_relative 'relationship_validation'

module JPie
  module Controller
    module RelationshipActions
      extend ActiveSupport::Concern
      include RelationshipValidation

      # GET /resources/:id/relationships/:relationship_name
      # Returns relationship linkage data
      def relationship_show
        validate_relationship_exists
        resource = find_resource
        relationship_data = get_relationship_data(resource)
        render_relationship_data(relationship_data)
      end

      # PATCH /resources/:id/relationships/:relationship_name
      # Updates relationship linkage (replaces all relationships)
      def relationship_update
        validate_relationship_exists
        validate_relationship_update_request
        resource = find_resource
        relationship_data = parse_relationship_data
        update_relationship(resource, relationship_data)
        render_relationship_data(get_relationship_data(resource))
      end

      # POST /resources/:id/relationships/:relationship_name
      # Adds to relationship linkage (for to-many relationships)
      def relationship_create
        validate_relationship_exists
        validate_relationship_update_request
        resource = find_resource
        relationship_data = parse_relationship_data
        add_to_relationship(resource, relationship_data)
        render_relationship_data(get_relationship_data(resource))
      end

      # DELETE /resources/:id/relationships/:relationship_name
      # Removes from relationship linkage (for to-many relationships)
      def relationship_destroy
        validate_relationship_exists
        validate_relationship_update_request
        resource = find_resource
        relationship_data = parse_relationship_data
        remove_from_relationship(resource, relationship_data)
        render_relationship_data(get_relationship_data(resource))
      end

      private

      def find_resource
        resource_class.scope(context).find(params[:id])
      end

      def relationship_name
        @relationship_name ||= params[:relationship_name].to_sym
      end

      def relationship_config
        @relationship_config ||= resource_class._relationships[relationship_name]
      end

      def get_relationship_data(resource)
        relationship_method = relationship_name
        related_objects = resource.send(relationship_method)

        if related_objects.respond_to?(:each)
          # to-many relationship
          related_objects.map { |obj| { type: infer_type(obj), id: obj.id.to_s } }
        elsif related_objects
          # to-one relationship
          { type: infer_type(related_objects), id: related_objects.id.to_s }
        end
      end

      def parse_relationship_data
        body = request.body.read
        request.body.rewind
        parsed_body = JSON.parse(body)

        unless parsed_body.key?('data')
          raise JPie::Errors::BadRequestError.new(
            detail: 'Request must include a "data" member'
          )
        end

        parsed_body['data']
      end

      def update_relationship(resource, relationship_data)
        if relationship_data.nil?
          # Set relationship to null
          clear_relationship(resource)
        elsif relationship_data.is_a?(Array)
          # to-many relationship - replace all
          replace_to_many_relationship(resource, relationship_data)
        elsif relationship_data.is_a?(Hash)
          # to-one relationship - replace
          replace_to_one_relationship(resource, relationship_data)
        else
          raise JPie::Errors::BadRequestError.new(
            detail: 'Relationship data must be null, an object, or an array of objects'
          )
        end
      end

      def add_to_relationship(resource, relationship_data)
        unless relationship_data.is_a?(Array)
          raise JPie::Errors::BadRequestError.new(
            detail: 'Adding to relationships requires an array of resource identifier objects'
          )
        end

        related_objects = find_related_objects(relationship_data)
        association = association_for_resource(resource)

        related_objects.each do |related_object|
          association << related_object unless association.include?(related_object)
        end
      end

      def remove_from_relationship(resource, relationship_data)
        unless relationship_data.is_a?(Array)
          raise JPie::Errors::BadRequestError.new(
            detail: 'Removing from relationships requires an array of resource identifier objects'
          )
        end

        related_objects = find_related_objects(relationship_data)
        association = association_for_resource(resource)

        related_objects.each do |related_object|
          association.delete(related_object)
        end
      end

      def clear_relationship(resource)
        association_name = association_name_for_relationship
        resource.send("#{association_name}=", nil)
        resource.save!
      end

      def replace_to_many_relationship(resource, relationship_data)
        related_objects = find_related_objects(relationship_data)
        association_name = association_name_for_relationship
        resource.send("#{association_name}=", related_objects)
        resource.save!
      end

      def replace_to_one_relationship(resource, relationship_data)
        related_object = find_related_object(relationship_data)
        association_name = association_name_for_relationship
        resource.send("#{association_name}=", related_object)
        resource.save!
      end

      def find_related_objects(relationship_data)
        relationship_data.map { |data| find_related_object(data) }
      end

      def find_related_object(resource_identifier)
        validate_resource_identifier(resource_identifier)

        type = resource_identifier['type']
        id = resource_identifier['id']

        related_model_class = infer_model_class_from_type(type)
        related_model_class.find(id)
      end

      def association_for_resource(resource)
        association_name = association_name_for_relationship
        resource.send(association_name)
      end

      def association_name_for_relationship
        # For now, assume the relationship name matches the association name
        # This could be made more sophisticated to handle custom association names
        relationship_name
      end

      def infer_type(object)
        # Convert model class name to JSON:API type
        # e.g., "User" -> "users", "BlogPost" -> "blog-posts"
        object.class.name.underscore.dasherize.pluralize
      end

      def infer_model_class_from_type(type)
        # Convert JSON:API type back to model class
        # e.g., "users" -> User, "blog-posts" -> BlogPost
        class_name = type.singularize.underscore.camelize
        class_name.constantize
      end

      def render_relationship_data(relationship_data)
        response_data = { data: relationship_data }
        render json: response_data, status: :ok, content_type: 'application/vnd.api+json'
      end
    end
  end
end
