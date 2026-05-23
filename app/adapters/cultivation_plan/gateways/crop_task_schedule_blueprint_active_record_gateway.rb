# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CropTaskScheduleBlueprintActiveRecordGateway
        def initialize(ctx)
          @ctx = ctx
          @task_mapper = Adapters::CultivationPlan::Mappers::AgriculturalTaskMapper.new(ctx)
        end

        def copy_for_user_crops
          return unless @ctx.reference_crop_id_to_user_crop_id.present?

          calc = Domain::CultivationPlan::Calculators::PlanningDateCalculator

          @ctx.reference_crop_id_to_user_crop_id.each do |reference_crop_id, user_crop_id|
            reference_blueprints = ::CropTaskScheduleBlueprint
                                   .where(crop_id: reference_crop_id)
                                   .includes(:agricultural_task)
                                   .ordered
                                   .to_a
            next if reference_blueprints.empty?

            timestamp = Time.current
            allowed_columns = ::CropTaskScheduleBlueprint.column_names.map(&:to_sym)

            blueprint_attributes = reference_blueprints.map do |bp|
              reference_task_id = bp.source_agricultural_task_id.presence || bp.agricultural_task_id
              mapped_user_task_id = reference_task_id ? @task_mapper.user_agricultural_task_id_for(reference_task_id) : nil

              attrs = {
                crop_id: user_crop_id,
                agricultural_task_id: mapped_user_task_id,
                source_agricultural_task_id: reference_task_id,
                stage_order: bp.stage_order,
                stage_name: bp.stage_name,
                gdd_trigger: calc.normalize_decimal(bp.gdd_trigger),
                gdd_tolerance: calc.normalize_decimal(bp.gdd_tolerance),
                task_type: bp.task_type,
                source: bp.source,
                priority: bp.priority,
                amount: calc.normalize_decimal(bp.amount),
                amount_unit: bp.amount_unit,
                description: bp.description,
                weather_dependency: bp.weather_dependency,
                time_per_sqm: calc.normalize_decimal(bp.time_per_sqm),
                created_at: timestamp,
                updated_at: timestamp
              }

              attrs.select { |key, _| allowed_columns.include?(key) || [ :created_at, :updated_at ].include?(key) }
            end

            ::CropTaskScheduleBlueprint.transaction do
              ::CropTaskScheduleBlueprint.where(crop_id: user_crop_id).delete_all
              ::CropTaskScheduleBlueprint.insert_all!(blueprint_attributes)
            end
          end
        end
      end
    end
  end
end
