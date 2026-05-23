# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      class PestAiCreateFailure
        attr_reader :http_status, :message

        def initialize(http_status:, message:)
          @http_status = http_status
          @message = message
        end
      end
    end
  end
end
