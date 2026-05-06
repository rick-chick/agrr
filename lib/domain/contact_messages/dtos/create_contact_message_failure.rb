# frozen_string_literal: true

module Domain
  module ContactMessages
    module Dtos
      class CreateContactMessageFailure
        KIND_VALIDATION = :validation
        KIND_RECAPTCHA = :recaptcha
        KIND_RATE_LIMIT = :rate_limit

        attr_reader :kind, :errors, :message

        def self.validation(errors:)
          new(kind: KIND_VALIDATION, errors: errors)
        end

        def self.recaptcha(message:)
          new(kind: KIND_RECAPTCHA, message: message)
        end

        def self.rate_limit
          new(kind: KIND_RATE_LIMIT, message: "Too many requests")
        end

        def initialize(kind:, errors: nil, message: nil)
          @kind = kind
          @errors = errors
          @message = message
        end

        def validation?
          kind == KIND_VALIDATION
        end

        def recaptcha?
          kind == KIND_RECAPTCHA
        end

        def rate_limit?
          kind == KIND_RATE_LIMIT
        end
      end
    end
  end
end
