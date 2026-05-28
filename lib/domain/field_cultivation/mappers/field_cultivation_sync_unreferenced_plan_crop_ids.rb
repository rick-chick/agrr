# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Mappers
      # 同期後に field_cultivation から参照されなくなった cultivation_plan_crop の ID（I/O なし）。
      module FieldCultivationSyncUnreferencedPlanCropIds
        module_function

        # @param plan_snapshot [Dtos::FieldCultivationSyncPlanSnapshot]
        # @param referenced_crop_ids [Array<String, Integer>]
        # @return [Array<Integer>]
        def ids_to_delete(plan_snapshot:, referenced_crop_ids:)
          referenced = Array(referenced_crop_ids).map(&:to_s)
          return [] if referenced.empty?

          rows = plan_snapshot.plan_crop_rows
          all_ids = rows.map(&:plan_crop_id)
          retained_ids = rows.filter_map do |row|
            row.plan_crop_id if referenced.include?(row.crop_id)
          end
          all_ids - retained_ids
        end
      end
    end
  end
end
