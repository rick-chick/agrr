# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropStageDeleteInput
        attr_reader :crop_id, :stage_id

        def initialize(crop_id:, stage_id:)
          @crop_id = crop_id
          @stage_id = stage_id
        end
      end
    end
  end
end
