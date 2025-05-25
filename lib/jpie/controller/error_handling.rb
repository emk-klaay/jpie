# frozen_string_literal: true

require_relative 'error_handling/handler_setup'
require_relative 'error_handling/handlers'

module JPie
  module Controller
    module ErrorHandling
      extend ActiveSupport::Concern

      include HandlerSetup
      include Handlers

      included do
        # Use class_attribute to allow easy overriding
        class_attribute :jpie_error_handlers_enabled, default: true

        # Set up default handlers unless explicitly disabled
        setup_jpie_error_handlers if jpie_error_handlers_enabled
      end
    end
  end
end
