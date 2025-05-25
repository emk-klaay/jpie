# frozen_string_literal: true

module JPie
  module Controller
    module Rendering
      def resource_class
        # Default implementation that infers from controller name
        @resource_class ||= infer_resource_class
      end

      def serializer
        @serializer ||= JPie::Serializer.new(resource_class)
      end

      def deserializer
        @deserializer ||= JPie::Deserializer.new(resource_class)
      end

      protected

      def model_class
        resource_class.model
      end

      # More concise method names following Rails conventions
      def render_jsonapi(resource_or_resources, status: :ok, meta: nil, pagination: nil, original_scope: nil)
        includes = parse_include_params
        json_data = serializer.serialize(resource_or_resources, context, includes: includes)

        # Add pagination metadata and links if pagination is provided and valid
        if pagination && pagination[:per_page]
          add_pagination_metadata(json_data, resource_or_resources, pagination, original_scope)
        end

        json_data[:meta] = meta if meta

        render json: json_data, status:, content_type: 'application/vnd.api+json'
      end

      # Keep original methods for backward compatibility
      alias render_jsonapi_resource render_jsonapi
      alias render_jsonapi_resources render_jsonapi

      private

      def add_pagination_metadata(json_data, resources, pagination, original_scope)
        page = pagination[:page] || 1
        per_page = pagination[:per_page]

        # Get total count from the original scope before pagination
        total_count = get_total_count(resources, original_scope)
        total_pages = (total_count.to_f / per_page).ceil

        # Add pagination metadata
        json_data[:meta] ||= {}
        json_data[:meta][:pagination] = {
          page: page,
          per_page: per_page,
          total_pages: total_pages,
          total_count: total_count
        }

        # Add pagination links
        json_data[:links] = build_pagination_links(page, per_page, total_pages)
      end

      def get_total_count(resources, original_scope)
        # Use original scope if provided, otherwise fall back to resources
        scope_to_count = original_scope || resources

        # If scope is an ActiveRecord relation, get the count
        # Otherwise, if it's an array, get the length
        if scope_to_count.respond_to?(:count) && !scope_to_count.loaded?
          scope_to_count.count
        elsif scope_to_count.respond_to?(:size)
          scope_to_count.size
        else
          0
        end
      end

      def build_pagination_links(page, per_page, total_pages)
        url_components = extract_url_components
        pagination_data = { page: page, per_page: per_page, total_pages: total_pages }

        links = build_base_pagination_links(url_components, pagination_data)
        add_conditional_pagination_links(links, url_components, pagination_data)

        links
      end

      def extract_url_components
        base_url = request.respond_to?(:base_url) ? request.base_url : 'http://example.com'
        path = request.respond_to?(:path) ? request.path : '/resources'
        query_params = request.respond_to?(:query_parameters) ? request.query_parameters.except('page') : {}

        { base_url: base_url, path: path, query_params: query_params }
      end

      def build_base_pagination_links(url_components, pagination_data)
        full_url = url_components[:base_url] + url_components[:path]
        query_params = url_components[:query_params]
        page = pagination_data[:page]
        per_page = pagination_data[:per_page]
        total_pages = pagination_data[:total_pages]

        {
          self: build_page_url(full_url, query_params, page, per_page),
          first: build_page_url(full_url, query_params, 1, per_page),
          last: build_page_url(full_url, query_params, total_pages, per_page)
        }
      end

      def add_conditional_pagination_links(links, url_components, pagination_data)
        full_url = url_components[:base_url] + url_components[:path]
        query_params = url_components[:query_params]
        page = pagination_data[:page]
        per_page = pagination_data[:per_page]
        total_pages = pagination_data[:total_pages]

        links[:prev] = build_page_url(full_url, query_params, page - 1, per_page) if page > 1
        links[:next] = build_page_url(full_url, query_params, page + 1, per_page) if page < total_pages
      end

      def build_page_url(base_url, query_params, page_num, per_page)
        params = query_params.merge(
          'page' => page_num.to_s,
          'per_page' => per_page.to_s
        )
        query_string = params.respond_to?(:to_query) ? params.to_query : params.map { |k, v| "#{k}=#{v}" }.join('&')
        "#{base_url}?#{query_string}"
      end

      def infer_resource_class
        # Convert controller name to resource class name
        # e.g., "UsersController" -> "UserResource"
        # e.g., "Api::V1::UsersController" -> "UserResource"
        controller_name = self.class.name
        return nil unless controller_name&.end_with?('Controller')

        # Remove "Controller" suffix and any namespace
        base_name = controller_name.split('::').last.chomp('Controller')

        # Convert plural controller name to singular resource name
        # e.g., "Users" -> "User"
        singular_name = base_name.singularize
        resource_class_name = "#{singular_name}Resource"

        # Try to constantize the resource class
        resource_class_name.constantize
      end
    end
  end
end
