# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropShowDetailSunshineRequirementSnapshot
        attr_reader :id, :crop_stage_id, :minimum_sunshine_hours, :target_sunshine_hours

        def initialize(id:, crop_stage_id:, minimum_sunshine_hours:, target_sunshine_hours:)
          @id = id
          @crop_stage_id = crop_stage_id
          @minimum_sunshine_hours = minimum_sunshine_hours
          @target_sunshine_hours = target_sunshine_hours
          freeze
        end
      end
    end
  end
end
