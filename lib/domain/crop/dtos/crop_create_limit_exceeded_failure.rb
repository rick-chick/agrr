# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropCreateLimitExceededFailure
        attr_reader :message

        def initialize(message:)
          @message = message
        end
      end
    end
  end
end
