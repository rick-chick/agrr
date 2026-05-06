# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      # Shared failure payload for masters crop task template index / update / destroy API flows.
      # +reason+ examples: +:crop_not_found+, +:association_not_found+, +:validation_failed+
      class MastersCropTaskTemplateMastersApiFailureDto
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
