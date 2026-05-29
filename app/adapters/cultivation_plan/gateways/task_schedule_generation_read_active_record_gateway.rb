# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class TaskScheduleGenerationReadActiveRecordGateway <
          Domain::CultivationPlan::Gateways::TaskScheduleGenerationReadGateway
        CROP_STAGE_INCLUDES = {
          crop_stages: [
            :temperature_requirement,
            :thermal_requirement,
            :sunshine_requirement,
            :nutrient_requirement
          ]
        }.freeze

        def find_plan_row(plan_id:)
          plan = ::CultivationPlan.find(plan_id)
          Mappers::TaskScheduleGenerationPlanRowSnapshotMapper.from_model(plan)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def list_field_cultivation_rows(plan_id:)
          rows = ::FieldCultivation
                   .where(cultivation_plan_id: plan_id)
                   .includes(cultivation_plan_crop: :crop)
          rows.map { |fc| Mappers::TaskScheduleGenerationFieldCultivationRowSnapshotMapper.from_model(fc) }
        end

        def find_crop_row(crop_id:)
          crop = ::Crop.find(crop_id)
          Mappers::TaskScheduleGenerationCropRowSnapshotMapper.from_model(crop)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def list_crop_task_template_rows(crop_id:)
          ::CropTaskTemplate
            .where(crop_id: crop_id)
            .includes(:agricultural_task)
            .map { |row| Mappers::TaskScheduleGenerationCropTaskTemplateRowSnapshotMapper.from_model(row) }
        end

        def list_crop_task_schedule_blueprint_rows(crop_id:)
          ::CropTaskScheduleBlueprint
            .where(crop_id: crop_id)
            .includes(:agricultural_task)
            .order(:stage_order, :priority, :id)
            .map { |row| Mappers::TaskScheduleGenerationBlueprintRowSnapshotMapper.from_model(row) }
        end

        def build_crop_agrr_requirement(crop_id:)
          crop = ::Crop.includes(CROP_STAGE_INCLUDES).find(crop_id)
          Adapters::Crop::Mappers::CropAgrrRequirementMapper.build_from(crop)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
