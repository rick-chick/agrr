# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropShowDetailThermalRequirementSnapshot
        attr_reader :id, :crop_stage_id, :required_gdd

        def initialize(id:, crop_stage_id:, required_gdd:)
          @id = id
          @crop_stage_id = crop_stage_id
          @required_gdd = required_gdd
          freeze
        end
      end
    end
  end
end
