# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Mappers
      # allocation → cultivation_plan_crop_id（スナップショット上の全行を保持する契約に基づく）。
      module FieldCultivationSyncPlanCropResolver
        module_function

        # @param plan_snapshot [Dtos::FieldCultivationSyncPlanSnapshot]
        # @param allocation [Dtos::FieldCultivationSyncAllocationInput]
        # @return [Integer, nil]
        def resolve_plan_crop_id(plan_snapshot:, allocation:)
          field_cultivation_id = field_cultivation_id_from_allocation(allocation)
          if field_cultivation_id
            existing = plan_snapshot.existing_field_cultivations_by_id[field_cultivation_id]
            return existing&.cultivation_plan_crop_id
          end

          crop_id = allocation.crop_id.to_s
          matches = plan_snapshot.plan_crop_rows.select { |row| row.crop_id == crop_id }
          case matches.size
          when 0
            nil
          when 1
            matches.first.plan_crop_id
          else
            raise Errors::FieldCultivationSyncReferenceError.new(
              kind: Errors::FieldCultivationSyncReferenceError::KIND_PLAN_CROP_AMBIGUOUS,
              message: "multiple plan crops for crop_id",
              crop_id: crop_id,
              allocation_id: allocation.resolved_allocation_raw
            )
          end
        end

        def field_cultivation_id_from_allocation(allocation)
          return nil if allocation.allocation_id.nil?

          allocation.allocation_id.to_i
        end
        private_class_method :field_cultivation_id_from_allocation
      end
    end
  end
end
