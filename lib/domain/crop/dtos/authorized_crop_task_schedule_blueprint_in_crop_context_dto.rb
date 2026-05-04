# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      # 認可済み作物の子として CropTaskScheduleBlueprint を束ねる。
      class AuthorizedCropTaskScheduleBlueprintInCropContextDto
        attr_reader :persisted_crop, :persisted_blueprint

        def initialize(persisted_crop:, persisted_blueprint:)
          @persisted_crop = persisted_crop
          @persisted_blueprint = persisted_blueprint
        end
      end
    end
  end
end
