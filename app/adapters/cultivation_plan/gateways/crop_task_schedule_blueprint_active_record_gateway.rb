# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CropTaskScheduleBlueprintActiveRecordGateway <
          Domain::CultivationPlan::Gateways::CropTaskScheduleBlueprintGateway
        def list_by_crop_id(crop_id:)
          ::CropTaskScheduleBlueprint
            .where(crop_id: crop_id)
            .includes(:agricultural_task)
            .ordered
            .map { |bp| row_from_model(bp) }
        end

        def delete_by_crop_id(crop_id:)
          ::CropTaskScheduleBlueprint.where(crop_id: crop_id).delete_all
        end

        def bulk_create(records:)
          return if records.empty?

          timestamp = Time.current
          allowed_columns = ::CropTaskScheduleBlueprint.column_names.map(&:to_sym)

          blueprint_attributes = records.map do |attrs|
            row = {
              crop_id: attrs.crop_id,
              agricultural_task_id: attrs.agricultural_task_id,
              source_agricultural_task_id: attrs.source_agricultural_task_id,
              stage_order: attrs.stage_order,
              stage_name: attrs.stage_name,
              gdd_trigger: attrs.gdd_trigger,
              gdd_tolerance: attrs.gdd_tolerance,
              task_type: attrs.task_type,
              source: attrs.source,
              priority: attrs.priority,
              amount: attrs.amount,
              amount_unit: attrs.amount_unit,
              description: attrs.description,
              weather_dependency: attrs.weather_dependency,
              time_per_sqm: attrs.time_per_sqm,
              created_at: timestamp,
              updated_at: timestamp
            }
            row.select { |key, _| allowed_columns.include?(key) || [ :created_at, :updated_at ].include?(key) }
          end

          ::CropTaskScheduleBlueprint.insert_all!(blueprint_attributes)
        end

        private

        def row_from_model(bp)
          reference_task_id = bp.source_agricultural_task_id.presence || bp.agricultural_task_id
          Domain::CultivationPlan::Dtos::CropTaskScheduleBlueprintRow.new(
            agricultural_task_id: bp.agricultural_task_id,
            source_agricultural_task_id: reference_task_id,
            stage_order: bp.stage_order,
            stage_name: bp.stage_name,
            gdd_trigger: bp.gdd_trigger,
            gdd_tolerance: bp.gdd_tolerance,
            task_type: bp.task_type,
            source: bp.source,
            priority: bp.priority,
            amount: bp.amount,
            amount_unit: bp.amount_unit,
            description: bp.description,
            weather_dependency: bp.weather_dependency,
            time_per_sqm: bp.time_per_sqm
          )
        end
      end
    end
  end
end
