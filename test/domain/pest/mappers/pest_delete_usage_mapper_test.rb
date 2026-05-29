# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Mappers
      class PestDeleteUsageMapperTest < DomainLibTestCase
        Wire = Data.define(:pesticides_count)

        test "from_wire maps pesticides_count to PestDeleteUsage" do
          wire = Wire.new(pesticides_count: 5)

          dto = PestDeleteUsageMapper.from_wire(wire)

          assert_instance_of Dtos::PestDeleteUsage, dto
          assert_equal 5, dto.pesticides_count
        end
      end
    end
  end
end
