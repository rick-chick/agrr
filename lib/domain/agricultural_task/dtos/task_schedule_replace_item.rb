# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Dtos
      # TaskSchedule 一括置換時に Gateway が永続化する 1 行分（Interactor が組み立てる）。
      class TaskScheduleReplaceItem
        attr_reader :task_type, :agricultural_task_id, :name, :description,
                    :stage_name, :stage_order, :gdd_trigger, :gdd_tolerance,
                    :scheduled_date, :priority, :source, :status,
                    :weather_dependency, :time_per_sqm, :amount, :amount_unit

        def initialize(
          task_type:,
          agricultural_task_id:,
          name:,
          description:,
          stage_name:,
          stage_order:,
          gdd_trigger:,
          gdd_tolerance:,
          scheduled_date:,
          priority:,
          source:,
          status:,
          weather_dependency:,
          time_per_sqm:,
          amount:,
          amount_unit:
        )
          @task_type = task_type
          @agricultural_task_id = agricultural_task_id
          @name = name
          @description = description
          @stage_name = stage_name
          @stage_order = stage_order
          @gdd_trigger = gdd_trigger
          @gdd_tolerance = gdd_tolerance
          @scheduled_date = scheduled_date
          @priority = priority
          @source = source
          @status = status
          @weather_dependency = weather_dependency
          @time_per_sqm = time_per_sqm
          @amount = amount
          @amount_unit = amount_unit
        end
      end
    end
  end
end
