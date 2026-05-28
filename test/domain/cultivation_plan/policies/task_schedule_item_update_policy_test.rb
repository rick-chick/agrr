# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Policies
      class TaskScheduleItemUpdatePolicyTest < DomainLibTestCase
        setup do
          @calculator = Calculators::AmountUnitConversionCalculator.new
          @rescheduled_at = Time.utc(2026, 6, 1, 12, 0, 0)
        end

        def amount_snapshot(scheduled_date: Date.new(2026, 5, 1))
          Dtos::TaskScheduleItemAmountSnapshot.new(
            amount: BigDecimal("1"),
            amount_unit: "kg/ha",
            scheduled_date: scheduled_date
          )
        end

        test "build_update_attributes sets rescheduled when scheduled_date changes" do
          result = TaskScheduleItemUpdatePolicy.build_update_attributes(
            attributes_seed: { scheduled_date: "2026-06-15", name: "作業" },
            amount_snapshot: amount_snapshot,
            calculator: @calculator,
            rescheduled_at: @rescheduled_at
          )

          assert_equal Date.new(2026, 6, 15), result["scheduled_date"]
          assert_equal "作業", result["name"]
          assert_equal @rescheduled_at, result["rescheduled_at"]
          assert_equal(
            Domain::AgriculturalTask::Constants::TaskScheduleItemStatuses::RESCHEDULED,
            result["status"]
          )
        end

        test "build_update_attributes does not reschedule when scheduled_date unchanged" do
          result = TaskScheduleItemUpdatePolicy.build_update_attributes(
            attributes_seed: { scheduled_date: "2026-05-01" },
            amount_snapshot: amount_snapshot,
            calculator: @calculator,
            rescheduled_at: @rescheduled_at
          )

          assert_equal Date.new(2026, 5, 1), result["scheduled_date"]
          assert_nil result["rescheduled_at"]
          assert_nil result["status"]
        end

        test "build_update_attributes applies calculator unit conversion" do
          result = TaskScheduleItemUpdatePolicy.build_update_attributes(
            attributes_seed: { amount_unit: "g/m2", amount: "1.0" },
            amount_snapshot: amount_snapshot,
            calculator: @calculator,
            rescheduled_at: @rescheduled_at
          )

          assert_in_delta 0.1, result["amount"].to_f, 0.0001
          assert_equal "g/m2", result["amount_unit"]
        end

        test "build_update_attributes omits reschedule when scheduled_date blank" do
          result = TaskScheduleItemUpdatePolicy.build_update_attributes(
            attributes_seed: { name: "作業のみ" },
            amount_snapshot: amount_snapshot,
            calculator: @calculator,
            rescheduled_at: @rescheduled_at
          )

          assert_equal "作業のみ", result["name"]
          assert_nil result["rescheduled_at"]
          assert_nil result["status"]
        end
      end
    end
  end
end
