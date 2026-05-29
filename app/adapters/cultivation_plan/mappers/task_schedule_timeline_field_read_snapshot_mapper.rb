# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module TaskScheduleTimelineFieldReadSnapshotMapper
        Dtos = Domain::CultivationPlan::Dtos::TaskScheduleTimelineSnapshot

        module_function

        def field_context_from(field_cultivation)
          Dtos::FieldContextSnapshot.new(
            field_cultivation_id: field_cultivation&.id,
            id: field_cultivation&.id,
            name: field_cultivation&.cultivation_plan_field&.name,
            crop_name: field_cultivation&.cultivation_plan_crop&.name ||
              field_cultivation&.cultivation_plan_crop&.crop&.name,
            area_sqm: field_cultivation&.area,
            crop_id: field_cultivation&.cultivation_plan_crop_id,
            task_options: task_options_from(field_cultivation)
          )
        end

        def schedule_row_from(schedule)
          Dtos::ScheduleRowSnapshot.new(
            field_cultivation_id: schedule.field_cultivation_id,
            schedule: schedule_from(schedule)
          )
        end

        def schedule_from(schedule)
          items = schedule.task_schedule_items.map { |item| item_from(item, schedule.field_cultivation_id) }
          Dtos::ScheduleRead.new(category: schedule.category, items: items)
        end
        private_class_method :schedule_from

        def item_from(item, field_cultivation_id)
          Dtos::ItemRead.new(
            id: item.id,
            name: item.name,
            task_type: item.task_type,
            scheduled_date: item.scheduled_date,
            stage_name: item.stage_name,
            stage_order: item.stage_order,
            gdd_trigger: item.gdd_trigger,
            gdd_tolerance: item.gdd_tolerance,
            priority: item.priority,
            source: item.source,
            weather_dependency: item.weather_dependency,
            time_per_sqm: item.time_per_sqm,
            amount: item.amount,
            amount_unit: item.amount_unit,
            status: item.respond_to?(:status) ? item.status : nil,
            agricultural_task_id: item.agricultural_task_id,
            field_cultivation_id: field_cultivation_id,
            agricultural_task: agricultural_task_from(item.agricultural_task),
            actual_date: item.actual_date,
            actual_notes: item.actual_notes,
            rescheduled_at: item.rescheduled_at,
            cancelled_at: item.cancelled_at,
            completed_at: item.completed_at
          )
        end
        private_class_method :item_from

        def agricultural_task_from(task)
          return nil unless task

          Dtos::AgriculturalTaskRead.new(
            name: task.name,
            description: task.description,
            time_per_sqm: task.time_per_sqm,
            weather_dependency: task.weather_dependency,
            required_tools: Array(task.required_tools).presence,
            skill_level: task.skill_level,
            task_type: task.task_type
          )
        end
        private_class_method :agricultural_task_from

        def task_options_from(field_cultivation)
          crop = field_cultivation&.cultivation_plan_crop&.crop
          return [] unless crop

          crop.crop_task_templates.sort_by(&:name).map do |template|
            Dtos::TaskOptionRead.new(
              template_id: template.id,
              name: template.name,
              task_type: template.task_type ||
                Domain::AgriculturalTask::Constants::ScheduleItemTypes::FIELD_WORK,
              agricultural_task_id: template.agricultural_task_id,
              description: template.description,
              weather_dependency: template.weather_dependency,
              time_per_sqm: template.time_per_sqm,
              required_tools: Array(template.required_tools).presence,
              skill_level: template.skill_level
            )
          end
        end
        private_class_method :task_options_from
      end
    end
  end
end
