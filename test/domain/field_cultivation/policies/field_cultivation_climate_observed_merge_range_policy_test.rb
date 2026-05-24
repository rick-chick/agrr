# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Policies
      class FieldCultivationClimateObservedMergeRangePolicyTest < DomainLibTestCase
        test "caps observed end at today minus one" do
          decision = FieldCultivationClimateObservedMergeRangePolicy.resolve(
            display_start_date: nil,
            display_end_date: nil,
            cultivation_start_date: Date.new(2026, 1, 1),
            cultivation_end_date: Date.new(2026, 12, 31),
            today: Date.new(2026, 3, 10)
          )

          assert_not decision.skip?
          assert_equal Date.new(2026, 1, 1), decision.start_date
          assert_equal Date.new(2026, 3, 9), decision.end_date
        end

        test "skips when start after actual end" do
          decision = FieldCultivationClimateObservedMergeRangePolicy.resolve(
            display_start_date: Date.new(2026, 5, 1),
            display_end_date: Date.new(2026, 6, 1),
            cultivation_start_date: Date.new(2026, 1, 1),
            cultivation_end_date: Date.new(2026, 12, 31),
            today: Date.new(2026, 3, 1)
          )

          assert decision.skip?
        end
      end
    end
  end
end
