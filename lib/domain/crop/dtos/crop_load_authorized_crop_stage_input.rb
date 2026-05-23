# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropLoadAuthorizedCropStageInput
        attr_reader :crop_id, :crop_stage_id

        def initialize(crop_id:, crop_stage_id:)
          @crop_id = crop_id
          @crop_stage_id = crop_stage_id
        end
      end
    end
  end
end
