# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropStageDetailInputDto
        attr_reader :crop_stage_id

        def initialize(crop_stage_id:)
          @crop_stage_id = crop_stage_id
        end

        def self.from_hash(hash)
          new(
            crop_stage_id: hash[:crop_stage_id]
          )
        end
      end
    end
  end
end