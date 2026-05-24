# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 参照作物の CropTaskScheduleBlueprint をユーザー作物へコピーする。
      class CropTaskScheduleBlueprintCopyInteractor
        def initialize(
          blueprint_gateway:,
          task_mapping_port:,
          logger:
        )
          @blueprint_gateway = blueprint_gateway
          @task_mapping_port = task_mapping_port
          @logger = logger
        end

        # @param input [Domain::CultivationPlan::Dtos::CropTaskScheduleBlueprintCopyInput]
        def call(input)
          mapping = input.reference_crop_id_to_user_crop_id
          return if mapping.blank?

          mapping.each do |reference_crop_id, user_crop_id|
            copy_blueprints_for_pair(reference_crop_id: reference_crop_id, user_crop_id: user_crop_id)
          end
        end

        private

        def copy_blueprints_for_pair(reference_crop_id:, user_crop_id:)
          reference_blueprints = @blueprint_gateway.list_by_crop_id(crop_id: reference_crop_id)
          return if reference_blueprints.empty?

          create_records = reference_blueprints.map do |blueprint|
            reference_task_id = blueprint.source_agricultural_task_id.presence || blueprint.agricultural_task_id
            mapped_user_task_id = reference_task_id ? @task_mapping_port.user_task_id_for(reference_task_id: reference_task_id) : nil

            Dtos::CropTaskScheduleBlueprintCreateAttrs.new(
              crop_id: user_crop_id,
              agricultural_task_id: mapped_user_task_id,
              source_agricultural_task_id: reference_task_id,
              stage_order: blueprint.stage_order,
              stage_name: blueprint.stage_name,
              gdd_trigger: Calculators::PlanningDateCalculator.normalize_decimal(blueprint.gdd_trigger),
              gdd_tolerance: Calculators::PlanningDateCalculator.normalize_decimal(blueprint.gdd_tolerance),
              task_type: blueprint.task_type,
              source: blueprint.source,
              priority: blueprint.priority,
              amount: Calculators::PlanningDateCalculator.normalize_decimal(blueprint.amount),
              amount_unit: blueprint.amount_unit,
              description: blueprint.description,
              weather_dependency: blueprint.weather_dependency,
              time_per_sqm: Calculators::PlanningDateCalculator.normalize_decimal(blueprint.time_per_sqm)
            )
          end

          @blueprint_gateway.delete_by_crop_id(crop_id: user_crop_id)
          @blueprint_gateway.bulk_create(records: create_records)
        end
      end
    end
  end
end
