# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Mappers
      module PlanAllocationAdjustReadSnapshotMapper
        module_function

        # @param plan [::CultivationPlan] preload 済み
        # @param crop_agrr_requirement_builder [#build_from]
        # @return [Domain::CultivationPlan::Dtos::PlanAllocationAdjustReadSnapshot]
        def from_cultivation_plan(plan, crop_agrr_requirement_builder:)
          plan_rows_snapshot = PlanAllocationAdjustReadPlanRowsSnapshotMapper.from_cultivation_plan(plan)
          agrr_builders = plan.cultivation_plan_crops.map do |plan_crop|
            -> { crop_agrr_requirement_builder.build_from(plan_crop.crop) }
          end
          Domain::CultivationPlan::Mappers::PlanAllocationAdjustReadSnapshotMapper.from_snapshots(
            plan_rows_snapshot: plan_rows_snapshot,
            plan_crop_agrr_builders: agrr_builders
          )
        end
      end
    end
  end
end
