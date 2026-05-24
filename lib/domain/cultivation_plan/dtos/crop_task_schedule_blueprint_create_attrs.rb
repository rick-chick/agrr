# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class CropTaskScheduleBlueprintCreateAttrs
        attr_reader :crop_id, :agricultural_task_id, :source_agricultural_task_id, :stage_order, :stage_name,
                    :gdd_trigger, :gdd_tolerance, :task_type, :source, :priority, :amount, :amount_unit,
                    :description, :weather_dependency, :time_per_sqm

        def initialize(
          crop_id:,
          agricultural_task_id:,
          source_agricultural_task_id:,
          stage_order:,
          stage_name:,
          gdd_trigger:,
          gdd_tolerance:,
          task_type:,
          source:,
          priority:,
          amount:,
          amount_unit:,
          description:,
          weather_dependency:,
          time_per_sqm:
        )
          @crop_id = crop_id
          @agricultural_task_id = agricultural_task_id
          @source_agricultural_task_id = source_agricultural_task_id
          @stage_order = stage_order
          @stage_name = stage_name
          @gdd_trigger = gdd_trigger
          @gdd_tolerance = gdd_tolerance
          @task_type = task_type
          @source = source
          @priority = priority
          @amount = amount
          @amount_unit = amount_unit
          @description = description
          @weather_dependency = weather_dependency
          @time_per_sqm = time_per_sqm
        end
      end
    end
  end
end
