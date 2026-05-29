# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Mappers
      class PestDeleteUsageMapperTest < DomainLibTestCase
        test "from_snapshot maps pesticides_count to PestDeleteUsage" do
          snapshot = Dtos::PestDeleteUsageSnapshot.new(pesticides_count: 5)

          dto = PestDeleteUsageMapper.from_snapshot(snapshot)

          assert_instance_of Dtos::PestDeleteUsage, dto
          assert_equal 5, dto.pesticides_count
        end
      end
    end
  end
end
