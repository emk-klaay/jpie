# frozen_string_literal: true

require 'active_support/concern'
require_relative 'controller/error_handling'
require_relative 'controller/parameter_parsing'
require_relative 'controller/rendering'
require_relative 'controller/crud_actions'
require_relative 'controller/json_api_validation'
require_relative 'controller/relationship_actions'
require_relative 'controller/related_actions'

module JPie
  module Controller
    extend ActiveSupport::Concern

    include ErrorHandling
    include ParameterParsing
    include Rendering
    include CrudActions
    include JsonApiValidation
    include RelationshipActions
    include RelatedActions

    # Relationship route actions
    def show_relationship
      relationship_show
    end

    def update_relationship
      relationship_update
    end

    def create_relationship
      relationship_create
    end

    def destroy_relationship
      relationship_destroy
    end

    def show_related
      related_show
    end
  end
end
