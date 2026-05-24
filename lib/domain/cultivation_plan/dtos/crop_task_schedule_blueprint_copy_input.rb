# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class CropTaskScheduleBlueprintCopyInput
        # @param reference_crop_id_to_user_crop_id [Hash{Integer => Integer}]
        def initialize(reference_crop_id_to_user_crop_id:)
          @reference_crop_id_to_user_crop_id = reference_crop_id_to_user_crop_id
        end

        attr_reader :reference_crop_id_to_user_crop_id
      end
    end
  end
end
