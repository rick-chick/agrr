# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class AuthorizedCropStageInCropContextDto
        attr_reader :crop_entity, :crop_stage_entity

        def initialize(crop_entity:, crop_stage_entity:)
          @crop_entity = crop_entity
          @crop_stage_entity = crop_stage_entity
        end
      end
    end
  end
end
