# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Mappers
      module CultivationPlanAdjustCropGrowthRowMapper
        module_function

        # @param snapshots [Array<Domain::CultivationPlan::Dtos::CultivationPlanAdjustPlanCropGrowthSnapshot>]
        # @return [Array<Domain::CultivationPlan::Dtos::CultivationPlanAdjustCropGrowthRow>]
        def from_snapshots(snapshots)
          snapshots.map { |snapshot| to_row(snapshot) }
        end

        # @param snapshot [Domain::CultivationPlan::Dtos::CultivationPlanAdjustPlanCropGrowthSnapshot]
        # @return [Domain::CultivationPlan::Dtos::CultivationPlanAdjustCropGrowthRow]
        def to_row(snapshot)
          Dtos::CultivationPlanAdjustCropGrowthRow.new(
            crop_name: snapshot.crop_name,
            growth_stage_count: snapshot.growth_stage_count
          )
        end
      end
    end
  end
end
