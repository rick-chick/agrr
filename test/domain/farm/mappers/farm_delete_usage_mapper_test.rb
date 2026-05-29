# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Farm
    module Mappers
      class FarmDeleteUsageMapperTest < DomainLibTestCase
        Wire = Data.define(:free_crop_plans_count)

        test "from_wire maps free_crop_plans_count to FarmDeleteUsage" do
          wire = Wire.new(free_crop_plans_count: 4)

          dto = FarmDeleteUsageMapper.from_wire(wire)

          assert_instance_of Dtos::FarmDeleteUsage, dto
          assert_equal 4, dto.free_crop_plans_count
        end
      end
    end
  end
end
