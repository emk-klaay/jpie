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
  end
end
