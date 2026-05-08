# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropStageCreateInputDto
        attr_reader :crop_id, :payload

        def initialize(crop_id:, payload:)
          @crop_id = crop_id
          @payload = payload
        end
      end
    end
  end
end
