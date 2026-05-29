# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanRestPlanReadActiveRecordGateway <
          Domain::CultivationPlan::Gateways::CultivationPlanRestPlanReadGateway
        def find_plan_header_snapshot_by_plan_id(plan_id:)
          plan = ::CultivationPlan.includes(:farm).find(plan_id.to_i)
          Mappers::CultivationPlanRestPlanHeaderSnapshotMapper.from_plan(plan)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def list_rest_plan_field_row_snapshots_by_plan_id(plan_id:)
          ensure_plan_exists!(plan_id)
          ::CultivationPlanField
            .where(cultivation_plan_id: plan_id)
            .map { |field| Mappers::CultivationPlanRestPlanFieldRowSnapshotMapper.from_field(field) }
        end

        def list_rest_plan_crop_row_snapshots_by_plan_id(plan_id:)
          ensure_plan_exists!(plan_id)
          ::CultivationPlanCrop
            .where(cultivation_plan_id: plan_id)
            .map { |crop| Mappers::CultivationPlanRestPlanCropRowSnapshotMapper.from_plan_crop(crop) }
        end

        def list_rest_plan_cultivation_row_snapshots_by_plan_id(plan_id:)
          ensure_plan_exists!(plan_id)
          ::FieldCultivation
            .includes(:cultivation_plan_field, :cultivation_plan_crop)
            .where(cultivation_plan_id: plan_id)
            .map do |fc|
              Mappers::CultivationPlanRestPlanCultivationRowSnapshotMapper.from_field_cultivation(fc)
            end
        end

        def list_palette_crop_ids_by_plan_id(plan_id:)
          ensure_plan_exists!(plan_id)
          ::CultivationPlanCrop
            .includes(:crop)
            .where(cultivation_plan_id: plan_id)
            .map { |cpc| cpc.crop&.id }
            .compact
        end

        private

        def ensure_plan_exists!(plan_id)
          ::CultivationPlan.find(plan_id.to_i)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
