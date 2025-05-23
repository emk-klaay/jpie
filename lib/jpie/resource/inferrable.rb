# frozen_string_literal: true

module JPie
  class Resource
    module Inferrable
      extend ActiveSupport::Concern

      included do
        class_attribute :_type, :_model_class
      end

      class_methods do
        def model(model_class = nil)
          if model_class
            self._model_class = model_class
          else
            _model_class || infer_model_class
          end
        end

        def type(type_name = nil)
          if type_name
            self._type = type_name.to_s
          else
            _type || infer_type_name
          end
        end

        private

        def infer_model_class
          name.chomp('Resource').constantize
        rescue NameError
          nil
        end

        def infer_type_name
          model&.model_name&.plural || name.chomp('Resource').underscore.pluralize
        end
      end
    end
  end
end
