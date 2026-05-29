# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class PlanAllocationAdjustReadPlanCropRowSnapshot
        attr_reader :crop_id, :crop_name, :groups, :crop_stage_count

        def initialize(crop_id:, crop_name:, groups:, crop_stage_count:)
          @crop_id = crop_id
          @crop_name = crop_name
          @groups = groups
          @crop_stage_count = crop_stage_count
          freeze
        end
      end
    end
  end
end
