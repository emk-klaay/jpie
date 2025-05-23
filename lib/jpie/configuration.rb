# frozen_string_literal: true

module JPie
  class Configuration
    attr_accessor :default_page_size, :maximum_page_size, :json_key_format

    def initialize
      @default_page_size = 20
      @maximum_page_size = 1000
      @json_key_format = :dasherized
    end

    def json_key_format=(format)
      unless %i[dasherized underscored camelized].include?(format)
        raise ArgumentError, 'json_key_format must be one of :dasherized, :underscored, :camelized'
      end

      @json_key_format = format
    end
  end
end
