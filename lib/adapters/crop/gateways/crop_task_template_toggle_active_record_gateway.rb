# frozen_string_literal: true

module Adapters
  module Crop
    module Gateways
      class CropTaskTemplateToggleActiveRecordGateway < Domain::Crop::Gateways::CropTaskTemplateToggleGateway
        def toggle_build_snapshot!(crop:, agricultural_task:)
          if (existing_template = crop.crop_task_templates.find_by(agricultural_task: agricultural_task))
            remove_template_and_blueprints(crop: crop, agricultural_task: agricultural_task, existing_template: existing_template)
          else
            add_template_and_blueprint(crop: crop, agricultural_task: agricultural_task)
          end

          crop.crop_task_templates.reload
          build_result(crop: crop)
        end

        private

        def remove_template_and_blueprints(crop:, agricultural_task:, existing_template:)
          related_blueprints = crop.crop_task_schedule_blueprints.where(agricultural_task: agricultural_task)
          related_blueprints.destroy_all if related_blueprints.any?

          existing_template.destroy
        end

        def add_template_and_blueprint(crop:, agricultural_task:)
          crop.crop_task_templates.create!(
            agricultural_task: agricultural_task,
            name: agricultural_task.name,
            description: agricultural_task.description,
            time_per_sqm: agricultural_task.time_per_sqm,
            weather_dependency: agricultural_task.weather_dependency,
            required_tools: agricultural_task.required_tools,
            skill_level: agricultural_task.skill_level
          )

          create_blueprint_for_template(crop: crop, agricultural_task: agricultural_task)
        end

        def create_blueprint_for_template(crop:, agricultural_task:)
          existing_blueprints = crop.crop_task_schedule_blueprints
          max_stage_order = existing_blueprints.maximum(:stage_order) || -1
          max_priority = existing_blueprints.maximum(:priority) || 0

          existing_blueprint = existing_blueprints.find_by(
            agricultural_task: agricultural_task,
            source: "manual"
          )
          return existing_blueprint if existing_blueprint

          template = crop.crop_task_templates.find_by(agricultural_task: agricultural_task)

          crop.crop_task_schedule_blueprints.create!(
            agricultural_task: agricultural_task,
            stage_order: max_stage_order + 1,
            gdd_trigger: BigDecimal("0.0"),
            task_type: TaskScheduleItem::FIELD_WORK_TYPE,
            source: "manual",
            priority: max_priority + 1,
            description: template&.description || agricultural_task.description || agricultural_task.name,
            weather_dependency: template&.weather_dependency || agricultural_task.weather_dependency,
            time_per_sqm: template&.time_per_sqm || agricultural_task.time_per_sqm,
            stage_name: nil,
            gdd_tolerance: nil,
            amount: nil,
            amount_unit: nil
          )
        end

        def build_result(crop:)
          Domain::Crop::Dtos::CropToggleTaskTemplateSnapshotDto.new(
            available_agricultural_tasks: available_agricultural_tasks_for_crop(crop),
            selected_task_ids: selected_task_ids_for_crop(crop),
            task_schedule_blueprints: crop.crop_task_schedule_blueprints.includes(:agricultural_task).ordered
          )
        end

        def available_agricultural_tasks_for_crop(crop)
          if !crop.is_reference && crop.user_id.present?
            tasks = AgriculturalTask.user_owned.where(user_id: crop.user_id)
            tasks = tasks.where(region: crop.region) if crop.region.present?
            return tasks.order(:name)
          end

          if crop.is_reference
            tasks = AgriculturalTask.reference
            tasks = tasks.where(region: crop.region) if crop.region.present?
            return tasks.order(:name)
          end

          AgriculturalTask.none
        end

        def selected_task_ids_for_crop(crop)
          crop.crop_task_templates.pluck(:agricultural_task_id).compact.uniq
        end
      end
    end
  end
end
