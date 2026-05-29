# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # Task schedule 生成 read gateway が返す行スナップショット。
      module TaskScheduleGenerationReadSnapshots
        PlanRowSnapshot = Data.define(:id, :predicted_weather_data, :calculated_planning_start_date)
        FieldCultivationRowSnapshot = Data.define(:id, :start_date, :crop_id)
        CropRowSnapshot = Data.define(:id, :name)
        CropTaskTemplateRowSnapshot = Data.define(:agricultural_task)
        BlueprintRowSnapshot = Data.define(
          :id,
          :task_type,
          :gdd_trigger,
          :gdd_tolerance,
          :description,
          :stage_name,
          :stage_order,
          :priority,
          :source,
          :weather_dependency,
          :time_per_sqm,
          :amount,
          :amount_unit,
          :agricultural_task
        )
      end
    end
  end
end
