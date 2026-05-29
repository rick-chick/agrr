# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # Task schedule 生成 read gateway が返す行スナップショット（Rust struct 1:1 用の名前付き class）。
      module TaskScheduleGenerationReadSnapshots
        class PlanRowSnapshot
          attr_reader :id, :predicted_weather_data, :calculated_planning_start_date

          def initialize(id:, predicted_weather_data:, calculated_planning_start_date:)
            @id = id
            @predicted_weather_data = predicted_weather_data
            @calculated_planning_start_date = calculated_planning_start_date
            freeze
          end
        end

        class FieldCultivationRowSnapshot
          attr_reader :id, :start_date, :crop_id

          def initialize(id:, start_date:, crop_id:)
            @id = id
            @start_date = start_date
            @crop_id = crop_id
            freeze
          end
        end

        class CropRowSnapshot
          attr_reader :id, :name

          def initialize(id:, name:)
            @id = id
            @name = name
            freeze
          end
        end

        class CropTaskTemplateRowSnapshot
          attr_reader :agricultural_task

          def initialize(agricultural_task:)
            @agricultural_task = agricultural_task
            freeze
          end
        end

        class BlueprintRowSnapshot
          attr_reader :id,
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
            freeze
          end
        end
      end
    end
  end
end
