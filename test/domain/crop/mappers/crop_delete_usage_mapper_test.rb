# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Mappers
      class CropDeleteUsageMapperTest < DomainLibTestCase
        test "from_snapshot maps counts to CropDeleteUsage" do
          snapshot = Dtos::CropDeleteUsageSnapshot.new(
            cultivation_plan_crops_count: 2,
            free_crop_plans_count: 3,
            pesticides_count: 1
          )

          dto = CropDeleteUsageMapper.from_snapshot(snapshot)

          assert_instance_of Dtos::CropDeleteUsage, dto
          assert_equal 2, dto.cultivation_plan_crops_count
          assert_equal 3, dto.free_crop_plans_count
          assert_equal 1, dto.pesticides_count
        end
      end
    end
  end
end
