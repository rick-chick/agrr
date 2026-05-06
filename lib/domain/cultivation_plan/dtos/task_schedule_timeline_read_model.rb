# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      class TaskScheduleTimelineReadModel
        attr_reader :plan, :fields, :scheduled_dates

        def initialize(plan:, fields:, scheduled_dates:)
          @plan = plan
          @fields = fields
          @scheduled_dates = scheduled_dates
        end

        class PlanRead
          attr_reader :id, :display_name, :status, :planning_start_date, :planning_end_date, :timeline_generated_at

          def initialize(id:, display_name:, status:, planning_start_date:, planning_end_date:, timeline_generated_at:)
            @id = id
            @display_name = display_name
            @status = status
            @planning_start_date = planning_start_date
            @planning_end_date = planning_end_date
            @timeline_generated_at = timeline_generated_at
          end
        end

        class FieldRead
          attr_reader :id, :name, :crop_name, :area_sqm, :field_cultivation_id, :crop_id, :task_options, :schedules

          def initialize(id:, name:, crop_name:, area_sqm:, field_cultivation_id:, crop_id:, task_options:, schedules:)
            @id = id
            @name = name
            @crop_name = crop_name
            @area_sqm = area_sqm
            @field_cultivation_id = field_cultivation_id
            @crop_id = crop_id
            @task_options = task_options
            @schedules = schedules
          end
        end

        class ScheduleRead
          attr_reader :category, :items

          def initialize(category:, items:)
            @category = category
            @items = items
          end
        end

        class ItemRead
          attr_reader :id, :name, :task_type, :scheduled_date, :stage_name, :stage_order, :gdd_trigger, :gdd_tolerance,
                      :priority, :source, :weather_dependency, :time_per_sqm, :amount, :amount_unit, :status,
                      :agricultural_task_id, :field_cultivation_id, :agricultural_task, :actual_date, :actual_notes,
                      :rescheduled_at, :cancelled_at, :completed_at

          def initialize(id:, name:, task_type:, scheduled_date:, stage_name:, stage_order:, gdd_trigger:, gdd_tolerance:,
                         priority:, source:, weather_dependency:, time_per_sqm:, amount:, amount_unit:, status:,
                         agricultural_task_id:, field_cultivation_id:, agricultural_task:, actual_date:, actual_notes:,
                         rescheduled_at:, cancelled_at:, completed_at:)
            @id = id
            @name = name
            @task_type = task_type
            @scheduled_date = scheduled_date
            @stage_name = stage_name
            @stage_order = stage_order
            @gdd_trigger = gdd_trigger
            @gdd_tolerance = gdd_tolerance
            @priority = priority
            @source = source
            @weather_dependency = weather_dependency
            @time_per_sqm = time_per_sqm
            @amount = amount
            @amount_unit = amount_unit
            @status = status
            @agricultural_task_id = agricultural_task_id
            @field_cultivation_id = field_cultivation_id
            @agricultural_task = agricultural_task
            @actual_date = actual_date
            @actual_notes = actual_notes
            @rescheduled_at = rescheduled_at
            @cancelled_at = cancelled_at
            @completed_at = completed_at
          end
        end

        class TaskOptionRead
          attr_reader :template_id, :name, :task_type, :agricultural_task_id, :description, :weather_dependency,
                      :time_per_sqm, :required_tools, :skill_level

          def initialize(template_id:, name:, task_type:, agricultural_task_id:, description:, weather_dependency:,
                         time_per_sqm:, required_tools:, skill_level:)
            @template_id = template_id
            @name = name
            @task_type = task_type
            @agricultural_task_id = agricultural_task_id
            @description = description
            @weather_dependency = weather_dependency
            @time_per_sqm = time_per_sqm
            @required_tools = required_tools
            @skill_level = skill_level
          end
        end

        class AgriculturalTaskRead
          attr_reader :name, :description, :time_per_sqm, :weather_dependency, :required_tools, :skill_level, :task_type

          def initialize(name:, description:, time_per_sqm:, weather_dependency:, required_tools:, skill_level:, task_type:)
            @name = name
            @description = description
            @time_per_sqm = time_per_sqm
            @weather_dependency = weather_dependency
            @required_tools = required_tools
            @skill_level = skill_level
            @task_type = task_type
          end
        end
      end
    end
  end
end
