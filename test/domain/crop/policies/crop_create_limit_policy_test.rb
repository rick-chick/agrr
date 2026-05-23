# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Policies
      class CropCreateLimitPolicyTest < DomainLibTestCase
        test "limit_exceeded? is false for reference crop regardless of count" do
          assert_not CropCreateLimitPolicy.limit_exceeded?(
            existing_non_reference_count: 100,
            is_reference: true
          )
        end

        test "limit_exceeded? is false below max for user crop" do
          assert_not CropCreateLimitPolicy.limit_exceeded?(
            existing_non_reference_count: 19,
            is_reference: false
          )
        end

        test "limit_exceeded? is true at max for user crop" do
          assert CropCreateLimitPolicy.limit_exceeded?(
            existing_non_reference_count: CropCreateLimitPolicy::MAX_NON_REFERENCE_CROPS_PER_USER,
            is_reference: false
          )
        end

        test "limit_exceeded? is true above max for user crop" do
          assert CropCreateLimitPolicy.limit_exceeded?(
            existing_non_reference_count: CropCreateLimitPolicy::MAX_NON_REFERENCE_CROPS_PER_USER + 1,
            is_reference: false
          )
        end
      end
    end
  end
end
