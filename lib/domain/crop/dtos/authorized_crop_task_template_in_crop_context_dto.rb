# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      # 認可済み作物の子として CropTaskTemplate を束ねる（マスタ HTML/API 用）。
      class AuthorizedCropTaskTemplateInCropContextDto
        attr_reader :persisted_crop, :persisted_crop_task_template

        def initialize(persisted_crop:, persisted_crop_task_template:)
          @persisted_crop = persisted_crop
          @persisted_crop_task_template = persisted_crop_task_template
        end
      end
    end
  end
end
