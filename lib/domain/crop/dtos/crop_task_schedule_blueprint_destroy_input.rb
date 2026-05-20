# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropTaskScheduleBlueprintDestroyInput
        attr_reader :user_id, :crop_id, :blueprint_id

        def initialize(user_id:, crop_id:, blueprint_id:)
          @user_id = user_id
          @crop_id = crop_id
          @blueprint_id = blueprint_id
        end
      end
    end
  end
end
