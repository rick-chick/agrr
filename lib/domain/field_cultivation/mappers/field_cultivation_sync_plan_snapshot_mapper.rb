# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Mappers
      module FieldCultivationSyncPlanSnapshotMapper
        module_function

        # @param plan_id [Integer]
        # @param plan_field_ids [Array<Integer>]
        # @param plan_crop_rows [Array<Dtos::FieldCultivationSyncPlanCropEntry>]
        # @param existing_field_cultivation_entries [Array<Dtos::FieldCultivationSyncExistingFieldCultivationEntry>]
        # @return [Dtos::FieldCultivationSyncPlanSnapshot]
        def from_snapshots(plan_id:, plan_field_ids:, plan_crop_rows:, existing_field_cultivation_entries:)
          plan_fields_by_id = Array(plan_field_ids).each_with_object({}) do |field_id, hash|
            hash[field_id] = field_id
          end
          existing_by_id = Array(existing_field_cultivation_entries).each_with_object({}) do |entry, hash|
            hash[entry.field_cultivation_id] = entry
          end

          Dtos::FieldCultivationSyncPlanSnapshot.new(
            plan_id: plan_id,
            plan_fields_by_id: plan_fields_by_id,
            plan_crop_rows: plan_crop_rows,
            existing_field_cultivations_by_id: existing_by_id
          )
        end
      end
    end
  end
end
