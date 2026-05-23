# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      class FarmCreateLimitExceededFailure
        attr_reader :message

        def initialize(message:)
          @message = message
        end
      end
    end
  end
end
