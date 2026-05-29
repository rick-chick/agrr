# frozen_string_literal: true

module Adapters
  module FieldCultivation
    module Gateways
      class FieldCultivationSyncPlanReadActiveRecordGateway <
          Domain::FieldCultivation::Gateways::FieldCultivationSyncPlanReadGateway
        Dtos = Domain::FieldCultivation::Dtos

        def list_sync_plan_field_ids_by_plan_id(plan_id:)
          ensure_plan_exists!(plan_id)
          ::CultivationPlanField.where(cultivation_plan_id: plan_id).pluck(:id)
        end

        def list_sync_plan_crop_entries_by_plan_id(plan_id:)
          ensure_plan_exists!(plan_id)
          ::CultivationPlanCrop
            .includes(:crop)
            .where(cultivation_plan_id: plan_id)
            .map { |plan_crop| Mappers::FieldCultivationSyncPlanCropEntrySnapshotMapper.from_plan_crop(plan_crop) }
        end

        def list_sync_existing_field_cultivation_entries_by_plan_id(plan_id:)
          ensure_plan_exists!(plan_id)
          ::FieldCultivation
            .includes(cultivation_plan_crop: :crop)
            .where(cultivation_plan_id: plan_id)
            .map do |fc|
              Mappers::FieldCultivationSyncExistingFieldCultivationEntrySnapshotMapper.from_field_cultivation(fc)
            end
        end

        private

        def ensure_plan_exists!(plan_id)
          ::CultivationPlan.find(plan_id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
