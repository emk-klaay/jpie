# frozen_string_literal: true

require 'rails/railtie'

module JPie
  class Railtie < Rails::Railtie
    railtie_name :jpie

    config.jpie = ActiveSupport::OrderedOptions.new

    # Configure Rails inflections to preserve JPie casing
    initializer 'jpie.inflections' do
      ActiveSupport::Inflector.inflections(:en) do |inflect|
        inflect.acronym 'JPie'
      end
    end

    initializer 'jpie.configure' do |app|
      JPie.configure do |config|
        app.config.jpie.each do |key, value|
          config.public_send("#{key}=", value) if config.respond_to?("#{key}=")
        end
      end
    end

    initializer 'jpie.action_controller' do
      ActiveSupport.on_load(:action_controller) do
        extend JPie::Controller::ClassMethods if defined?(JPie::Controller::ClassMethods)
      end
    end

    generators do
      require 'jpie/generators/resource_generator'
    end
  end
end
