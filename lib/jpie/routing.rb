# frozen_string_literal: true

module JPie
  module Routing
    # Add jpie_resources method to Rails routing DSL that creates JSON:API compliant routes
    def jpie_resources(*resources)
      options = resources.extract_options!
      merged_options = build_merged_options(options)

      # Create standard RESTful routes for the resource
      resources(*resources, merged_options) do
        yield if block_given?
        add_jsonapi_relationship_routes(merged_options) if relationship_routes_allowed?(merged_options)
      end
    end

    private

    def build_merged_options(options)
      default_options = {
        defaults: { format: :json },
        constraints: { format: :json }
      }
      default_options.merge(options)
    end

    def relationship_routes_allowed?(merged_options)
      only_actions = merged_options[:only]
      except_actions = merged_options[:except]

      if only_actions
        # If only specific actions are allowed, don't add relationship routes
        # unless multiple member actions (show, update, destroy) are included
        (only_actions & %i[show update destroy]).size >= 2
      elsif except_actions
        # If actions are excluded, only add if member actions aren't excluded
        !except_actions.intersect?(%i[show update destroy])
      else
        true
      end
    end

    def add_jsonapi_relationship_routes(_merged_options)
      # These routes handle relationship management as per JSON:API spec
      member do
        # Routes for fetching and updating relationships
        # Pattern: /resources/:id/relationships/:relationship_name
        get 'relationships/*relationship_name', action: :show_relationship, as: :relationship
        patch 'relationships/*relationship_name', action: :update_relationship
        post 'relationships/*relationship_name', action: :create_relationship
        delete 'relationships/*relationship_name', action: :destroy_relationship

        # Routes for fetching related resources
        # Pattern: /resources/:id/:relationship_name
        get '*relationship_name', action: :show_related, as: :related
      end
    end
  end
end
