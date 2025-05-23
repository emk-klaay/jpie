# frozen_string_literal: true

module JPie
  class Configuration
    attr_accessor :default_page_size, :maximum_page_size

    def initialize
      @default_page_size = 20
      @maximum_page_size = 100
    end
  end
end
