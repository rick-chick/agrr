# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      module CultivationPlanWorkbenchSnapshotMapper
        module_function

        # @param rows [Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchRowsSnapshot]
        # @param available_crop_rows [Array]
        # @return [Domain::CultivationPlan::Dtos::CultivationPlanWorkbenchSnapshot]
        def to_snapshot(rows:, available_crop_rows:)
          Dtos::CultivationPlanWorkbenchSnapshot.new(
            plan: rows.plan,
            fields: rows.fields,
            crops: rows.crops,
            cultivations: rows.cultivations,
            available_crop_rows: available_crop_rows
          )
        end
      end
    end
  end
end
