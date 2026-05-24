# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Mappers
      class CultivationPlanAdjustCropGrowthRowMapperTest < DomainLibTestCase
        test "maps snapshots to growth rows" do
          snapshots = [
            Dtos::CultivationPlanAdjustPlanCropGrowthSnapshot.new(
              crop_name: "Tomato",
              growth_stage_count: 3
            ),
            Dtos::CultivationPlanAdjustPlanCropGrowthSnapshot.new(
              crop_name: "Lettuce",
              growth_stage_count: 2
            )
          ]

          rows = CultivationPlanAdjustCropGrowthRowMapper.from_snapshots(snapshots)

          assert_equal 2, rows.length
          assert_equal "Tomato", rows[0].crop_name
          assert_equal 3, rows[0].growth_stage_count
          assert_equal "Lettuce", rows[1].crop_name
          assert_equal 2, rows[1].growth_stage_count
        end
      end
    end
  end
end
