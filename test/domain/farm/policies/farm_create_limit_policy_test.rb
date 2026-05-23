# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Farm
    module Policies
      class FarmCreateLimitPolicyTest < DomainLibTestCase
        test "limit_exceeded? is false below max" do
          assert_not FarmCreateLimitPolicy.limit_exceeded?(existing_non_reference_count: 3)
        end

        test "limit_exceeded? is false at max minus one" do
          assert_not FarmCreateLimitPolicy.limit_exceeded?(
            existing_non_reference_count: FarmCreateLimitPolicy::MAX_NON_REFERENCE_FARMS_PER_USER - 1
          )
        end

        test "limit_exceeded? is true at max" do
          assert FarmCreateLimitPolicy.limit_exceeded?(
            existing_non_reference_count: FarmCreateLimitPolicy::MAX_NON_REFERENCE_FARMS_PER_USER
          )
        end

        test "limit_exceeded? is true above max" do
          assert FarmCreateLimitPolicy.limit_exceeded?(
            existing_non_reference_count: FarmCreateLimitPolicy::MAX_NON_REFERENCE_FARMS_PER_USER + 1
          )
        end
      end
    end
  end
end
