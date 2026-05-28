# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Mappers
      module FieldCultivationSyncApplyMapper
        module_function

        # @param plan_snapshot [Dtos::FieldCultivationSyncPlanSnapshot]
        # @param target_snapshot [Dtos::FieldCultivationSyncTargetSnapshot]
        # @return [Dtos::FieldCultivationSyncApply]
        def to_apply(plan_snapshot:, target_snapshot:)
          existing_ids = plan_snapshot.existing_field_cultivation_ids.to_set
          desired_rows = target_snapshot.field_cultivation_rows

          field_cultivations_to_update = desired_rows.select do |row|
            row.field_cultivation_id.present? && existing_ids.include?(row.field_cultivation_id)
          end
          field_cultivations_to_create = desired_rows.reject do |row|
            row.field_cultivation_id.present? && existing_ids.include?(row.field_cultivation_id)
          end
          retained_ids = field_cultivations_to_update.map(&:field_cultivation_id)
          field_cultivation_ids_to_delete = existing_ids.to_a - retained_ids
          cultivation_plan_crop_ids_to_delete =
            FieldCultivationSyncUnreferencedPlanCropIds.ids_to_delete(
              plan_snapshot: plan_snapshot,
              referenced_crop_ids: target_snapshot.referenced_crop_ids
            )

          Dtos::FieldCultivationSyncApply.new(
            field_cultivations_to_update: field_cultivations_to_update,
            field_cultivations_to_create: field_cultivations_to_create,
            field_cultivation_ids_to_delete: field_cultivation_ids_to_delete,
            cultivation_plan_crop_ids_to_delete: cultivation_plan_crop_ids_to_delete,
            cultivation_plan_summary: target_snapshot.cultivation_plan_summary
          )
        end
      end
    end
  end
end
