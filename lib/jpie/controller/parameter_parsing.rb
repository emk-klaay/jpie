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

      def parse_pagination_params
        page_params = params[:page] || {}
        per_page_param = params[:per_page]

        {
          page: extract_page_number(page_params, per_page_param),
          per_page: extract_per_page_size(page_params, per_page_param)
        }
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

      def extract_page_number(page_params, per_page_param)
        page_number = determine_page_number(page_params)
        page_number = '1' if page_number.nil? && per_page_param.present?
        return 1 if page_number.blank?

        parsed_page = page_number.to_i
        parsed_page.positive? ? parsed_page : 1
      end

      def extract_per_page_size(page_params, per_page_param)
        per_page_size = determine_per_page_size(page_params, per_page_param)
        return nil if per_page_size.blank?

        parsed_size = per_page_size.to_i
        parsed_size.positive? ? parsed_size : nil
      end

      def determine_page_number(page_params)
        if page_params.is_a?(String) || page_params.is_a?(Integer)
          page_params
        else
          page_params[:number] || page_params['number']
        end
      end

      def determine_per_page_size(page_params, per_page_param)
        if page_params.is_a?(String) || page_params.is_a?(Integer)
          per_page_param
        else
          page_params[:size] || page_params['size'] || per_page_param
        end
      end
    end
  end
end
