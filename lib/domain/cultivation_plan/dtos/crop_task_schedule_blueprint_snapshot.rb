# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # CropTaskScheduleBlueprint の表示・生成用スナップショット
      class CropTaskScheduleBlueprintSnapshot
        attr_reader :id, :task_type, :gdd_trigger, :gdd_tolerance, :description, :stage_name, :stage_order,
                    :priority, :source, :weather_dependency, :time_per_sqm, :amount, :amount_unit, :agricultural_task

        def initialize(
          id:,
          task_type:,
          gdd_trigger:,
          gdd_tolerance:,
          description:,
          stage_name:,
          stage_order:,
          priority:,
          source:,
          weather_dependency:,
          time_per_sqm:,
          amount:,
          amount_unit:,
          agricultural_task:
        )
          @id = id
          @task_type = task_type
          @gdd_trigger = gdd_trigger
          @gdd_tolerance = gdd_tolerance
          @description = description
          @stage_name = stage_name
          @stage_order = stage_order
          @priority = priority
          @source = source
          @weather_dependency = weather_dependency
          @time_per_sqm = time_per_sqm
          @amount = amount
          @amount_unit = amount_unit
          @agricultural_task = agricultural_task
        end
      end
    end
  end
end
