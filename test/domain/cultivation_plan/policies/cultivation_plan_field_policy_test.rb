# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Policies
      class CultivationPlanFieldPolicyTest < DomainLibTestCase
        test "invalid_field_area? when zero or negative" do
          assert CultivationPlanFieldPolicy.invalid_field_area?(field_area: 0)
          assert CultivationPlanFieldPolicy.invalid_field_area?(field_area: -1)
          assert_not CultivationPlanFieldPolicy.invalid_field_area?(field_area: 0.1)
        end

        test "max_fields_reached? at MAX_FIELDS" do
          assert CultivationPlanFieldPolicy.max_fields_reached?(existing_field_count: FieldsAllocation::MAX_FIELDS)
          assert_not CultivationPlanFieldPolicy.max_fields_reached?(existing_field_count: FieldsAllocation::MAX_FIELDS - 1)
        end

        test "cannot_remove_last_field? when one field" do
          assert CultivationPlanFieldPolicy.cannot_remove_last_field?(existing_field_count: 1)
          assert_not CultivationPlanFieldPolicy.cannot_remove_last_field?(existing_field_count: 2)
        end

        test "cannot_remove_with_cultivations? when count positive" do
          assert CultivationPlanFieldPolicy.cannot_remove_with_cultivations?(cultivation_count: 1)
          assert_not CultivationPlanFieldPolicy.cannot_remove_with_cultivations?(cultivation_count: 0)
        end
      end
    end
  end
end
