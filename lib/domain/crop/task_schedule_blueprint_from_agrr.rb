# frozen_string_literal: true

module Domain
  module Crop
    # agrr の schedule / fertilize 応答ハッシュから、CropTaskScheduleBlueprint 相当の属性 Hash を組み立てる。
    # 永続化・AR には触れない。task_type は Domain::AgriculturalTask::Constants::ScheduleItemTypes（AR の単一ソースと一致）。
    module TaskScheduleBlueprintFromAgrr
      class << self
        def general_row(crop_id:, task:, agricultural_task_id:, template_description: nil, template_weather_dependency: nil, template_time_per_sqm: nil)
          agrr_task_name = task["name"] || task["description"]

          {
            crop_id: crop_id,
            agricultural_task_id: agricultural_task_id,
            stage_order: integer_value(task["stage_order"]),
            stage_name: task["stage_name"],
            gdd_trigger: decimal_value(task["gdd_trigger"]),
            gdd_tolerance: decimal_value(task["gdd_tolerance"]),
            task_type: schedule_item_types::FIELD_WORK,
            source: "agrr_schedule",
            priority: integer_value(task["priority"]),
            description: agrr_task_name || template_description,
            amount: nil,
            amount_unit: nil,
            weather_dependency: task["weather_dependency"] || template_weather_dependency,
            time_per_sqm: decimal_value(task["time_per_sqm"]) || template_time_per_sqm
          }
        end

        def fertilizer_row(crop_id:, entry:, index:, agricultural_task_id:, template_description: nil, template_weather_dependency: nil, template_time_per_sqm: nil)
          task_type = entry["task_type"] ||
            (index.zero? ? schedule_item_types::BASAL_FERTILIZATION : schedule_item_types::TOPDRESS_FERTILIZATION)
          fixed_stage_name = index.zero? ? "基肥" : "追肥"
          agrr_task_name = fixed_stage_name
          amount_raw = entry["amount_g_per_m2"]

          {
            crop_id: crop_id,
            agricultural_task_id: agricultural_task_id,
            stage_order: integer_value(entry["stage_order"]),
            stage_name: fixed_stage_name,
            gdd_trigger: decimal_value(entry["gdd_trigger"]),
            gdd_tolerance: decimal_value(entry["gdd_tolerance"]),
            task_type: task_type,
            source: "agrr_fertilize_plan",
            priority: integer_value(entry["priority"]),
            description: agrr_task_name || template_description,
            amount: decimal_value(amount_raw),
            amount_unit: entry["amount_unit"] || (amount_specified?(amount_raw) ? "g/m2" : nil),
            weather_dependency: entry["weather_dependency"] || template_weather_dependency,
            time_per_sqm: decimal_value(entry["time_per_sqm"]) || template_time_per_sqm
          }
        end

        def decimal_value(value)
          Domain::Shared::TypeConverters::BigDecimalConverter.cast(value)
        end

        def integer_value(value)
          Domain::Shared::TypeConverters::IntegerConverter.cast(value)
        end

        private

        def amount_specified?(amount_raw)
          return false if amount_raw.nil?
          return false if amount_raw.respond_to?(:empty?) && amount_raw.empty?

          true
        end

        def schedule_item_types
          Domain::AgriculturalTask::Constants::ScheduleItemTypes
        end
      end
    end
  end
end
