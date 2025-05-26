# frozen_string_literal: true

module JPie
  module Routing
    # Add jpie_resources method to Rails routing DSL
    def jpie_resources(*resources, &)
      options = resources.extract_options!

      # Set default controller options for JSON:API
      default_options = {
        defaults: { format: :json },
        constraints: { format: :json }
      }

      # Merge user options with defaults
      merged_options = default_options.merge(options)

      # Call the standard resources method with our options
      resources(*resources, merged_options, &)
    end
  end
end
