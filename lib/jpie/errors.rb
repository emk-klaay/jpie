# frozen_string_literal: true

module JPie
  module Errors
    class Error < StandardError
      attr_reader :status, :code, :title, :detail, :source

      def initialize(status:, code: nil, title: nil, detail: nil, source: nil)
        @status = status
        @code = code
        @title = title
        @detail = detail
        @source = source
        super(detail || title || 'An error occurred')
      end

      def to_hash
        {
          status: status.to_s,
          code:,
          title:,
          detail:,
          source:
        }.compact
      end
    end

    class ValidationError < Error
      def initialize(detail:, source: nil)
        super(status: 422, title: 'Validation Error', detail:, source:)
      end
    end

    class NotFoundError < Error
      def initialize(detail: 'Resource not found')
        super(status: 404, title: 'Not Found', detail:)
      end
    end

    class BadRequestError < Error
      def initialize(detail: 'Bad Request')
        super(status: 400, title: 'Bad Request', detail:)
      end
    end

    class UnauthorizedError < Error
      def initialize(detail: 'Unauthorized')
        super(status: 401, title: 'Unauthorized', detail:)
      end
    end

    class ForbiddenError < Error
      def initialize(detail: 'Forbidden')
        super(status: 403, title: 'Forbidden', detail:)
      end
    end

    class InternalServerError < Error
      def initialize(detail: 'Internal Server Error')
        super(status: 500, title: 'Internal Server Error', detail:)
      end
    end

    class ResourceError < Error
      def initialize(detail:)
        super(status: 500, title: 'Resource Error', detail:)
      end
    end

    # JSON:API Compliance Errors
    class InvalidJsonApiRequestError < BadRequestError
      def initialize(detail: 'Request is not JSON:API compliant')
        super
      end
    end

    class UnsupportedIncludeError < BadRequestError
      def initialize(include_path:, supported_includes: [])
        detail = if supported_includes.any?
                   "Unsupported include '#{include_path}'. Supported includes: #{supported_includes.join(', ')}"
                 else
                   "Unsupported include '#{include_path}'. No includes are supported for this resource"
                 end
        super(detail: detail)
      end
    end

    class UnsupportedSortFieldError < BadRequestError
      def initialize(sort_field:, supported_fields: [])
        detail = if supported_fields.any?
                   "Unsupported sort field '#{sort_field}'. Supported fields: #{supported_fields.join(', ')}"
                 else
                   "Unsupported sort field '#{sort_field}'. No sorting is supported for this resource"
                 end
        super(detail: detail)
      end
    end

    class InvalidSortParameterError < BadRequestError
      def initialize(detail: 'Invalid sort parameter format')
        super
      end
    end

    class InvalidIncludeParameterError < BadRequestError
      def initialize(detail: 'Invalid include parameter format')
        super
      end
    end
  end
end
