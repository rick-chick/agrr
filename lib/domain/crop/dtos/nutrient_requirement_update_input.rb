# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class NutrientRequirementUpdateInput
        attr_reader :crop_id, :stage_id, :payload

        def initialize(crop_id:, stage_id:, payload:)
          @crop_id = crop_id
          @stage_id = stage_id
          @payload = payload
        end
      end
    end
  end
end
