# frozen_string_literal: true

require 'active_support/concern'
require_relative 'controller/error_handling'
require_relative 'controller/parameter_parsing'
require_relative 'controller/rendering'
require_relative 'controller/crud_actions'

module JPie
  module Controller
    extend ActiveSupport::Concern

    include ErrorHandling
    include ParameterParsing
    include Rendering
    include CrudActions
  end
end
