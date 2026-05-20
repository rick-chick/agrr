# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class MastersCropTaskTemplateCreateFailure
        attr_reader :reason, :message, :errors

        def initialize(reason:, message: nil, errors: nil)
          @reason = reason
          @message = message
          @errors = errors
        end
      end
    end
  end
end
