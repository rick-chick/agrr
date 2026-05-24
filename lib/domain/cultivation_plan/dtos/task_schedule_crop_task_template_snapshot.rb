# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class TaskScheduleCropTaskTemplateSnapshot
        attr_reader :id,
          :crop_id,
          :name,
          :description,
          :task_type,
          :weather_dependency,
          :time_per_sqm,
          :agricultural_task_id

        def initialize(
          id:,
          crop_id:,
          name:,
          description:,
          task_type:,
          weather_dependency:,
          time_per_sqm:,
          agricultural_task_id:
        )
          @id = id
          @crop_id = crop_id
          @name = name
          @description = description
          @task_type = task_type
          @weather_dependency = weather_dependency
          @time_per_sqm = time_per_sqm
          @agricultural_task_id = agricultural_task_id
        end
      end
    end
  end
end
