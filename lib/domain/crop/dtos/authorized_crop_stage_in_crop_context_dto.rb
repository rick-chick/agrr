# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      # 認可済み作物の子として CropStage を一度に束ねる（Controller の二重取得・rescue 回避用）。
      class AuthorizedCropStageInCropContextDto
        attr_reader :persisted_crop, :persisted_crop_stage

        def initialize(persisted_crop:, persisted_crop_stage:)
          @persisted_crop = persisted_crop
          @persisted_crop_stage = persisted_crop_stage
        end
      end
    end
  end
end
