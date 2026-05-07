# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropTaskScheduleBlueprintUpdatePositionInputDto
        attr_reader :user_id, :crop_id, :blueprint_id, :gdd_trigger, :priority

        def initialize(user_id:, crop_id:, blueprint_id:, gdd_trigger: nil, priority: nil)
          @user_id = user_id
          @crop_id = crop_id
          @blueprint_id = blueprint_id
          @gdd_trigger = gdd_trigger
          @priority = priority
        end
      end
    end
  end
end
