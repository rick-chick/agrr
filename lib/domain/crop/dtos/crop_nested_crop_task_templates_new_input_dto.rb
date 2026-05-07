# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropNestedCropTaskTemplatesNewInputDto
        attr_reader :user_id, :crop_id

        def initialize(user_id:, crop_id:)
          @user_id = user_id
          @crop_id = crop_id
        end
      end
    end
  end
end
