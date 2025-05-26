# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'
require 'jpie/version'

module JPie
  autoload :Resource, 'jpie/resource'
  autoload :Serializer, 'jpie/serializer'
  autoload :Deserializer, 'jpie/deserializer'
  autoload :Controller, 'jpie/controller'
  autoload :Configuration, 'jpie/configuration'
  autoload :Errors, 'jpie/errors'
  autoload :Routing, 'jpie/routing'

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end
end

require 'jpie/railtie' if defined?(Rails)
