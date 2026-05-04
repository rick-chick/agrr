# frozen_string_literal: true

module Domain
  module ContactMessages
    module Dtos
      class CreateContactMessageFailure
        attr_reader :errors

        def initialize(errors:)
          @errors = errors
        end
      end
    end
  end
end
