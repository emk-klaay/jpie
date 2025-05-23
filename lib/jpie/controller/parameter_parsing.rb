# frozen_string_literal: true

module JPie
  module Controller
    module ParameterParsing
      def parse_include_params
        params[:include]&.split(',')&.map(&:strip) || []
      end

      def parse_sort_params
        params[:sort]&.split(',')&.map(&:strip) || []
      end

      def deserialize_params
        deserializer.deserialize(request.body.read, context)
      rescue JSON::ParserError => e
        raise JPie::Errors::BadRequestError.new(detail: "Invalid JSON: #{e.message}")
      end

      def context
        @context ||= build_context
      end

      private

      def build_context
        {
          current_user: try(:current_user),
          controller: self,
          action: action_name
        }
      end
    end
  end
end
