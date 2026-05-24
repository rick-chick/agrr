# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class TaskScheduleFieldCultivationSnapshot
        attr_reader :id, :cultivation_plan_crop_id, :crop_id

        def initialize(id:, cultivation_plan_crop_id:, crop_id:)
          @id = id
          @cultivation_plan_crop_id = cultivation_plan_crop_id
          @crop_id = crop_id
        end
      end
    end
  end
end
