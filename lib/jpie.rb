# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext'
require 'jpie/version'
require_relative 'jpie/resource'
require_relative 'jpie/errors'

# Load RSpec support if RSpec is defined
require_relative 'jpie/rspec' if defined?(RSpec)

module JPie
  autoload :Serializer, 'jpie/serializer'
  autoload :Deserializer, 'jpie/deserializer'
  autoload :Controller, 'jpie/controller'
  autoload :Configuration, 'jpie/configuration'
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
