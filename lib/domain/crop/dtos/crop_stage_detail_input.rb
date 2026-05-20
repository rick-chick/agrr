# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropStageDetailInput
        attr_reader :crop_stage_id

        def initialize(crop_stage_id:)
          @crop_stage_id = crop_stage_id
        end
      end
    end
  end
end
