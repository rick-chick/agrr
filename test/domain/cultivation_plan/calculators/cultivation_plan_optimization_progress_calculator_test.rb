# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Calculators
      class CultivationPlanOptimizationProgressCalculatorTest < DomainLibTestCase
        Calc = CultivationPlanOptimizationProgressCalculator

        FieldCultivationStub = Struct.new(:status, keyword_init: true)

        test "progress_percent returns 0 when list empty" do
          assert_equal 0, Calc.progress_percent(field_cultivations: [])
        end

        test "progress_percent counts status completed" do
          cultivations = [
            FieldCultivationStub.new(status: "completed"),
            FieldCultivationStub.new(status: "pending"),
            FieldCultivationStub.new(status: "completed")
          ]

          assert_equal 67, Calc.progress_percent(field_cultivations: cultivations)
        end

        test "progress_percent counts status_completed? when present" do
          completed_via_predicate = Object.new
          def completed_via_predicate.status
            "optimizing"
          end
          def completed_via_predicate.status_completed?
            true
          end

          assert_equal(
            100,
            Calc.progress_percent(field_cultivations: [completed_via_predicate])
          )
        end

        test "progress_percent returns 0 when none completed" do
          cultivations = [
            FieldCultivationStub.new(status: "pending"),
            FieldCultivationStub.new(status: "optimizing")
          ]

          assert_equal 0, Calc.progress_percent(field_cultivations: cultivations)
        end
      end
    end
  end
end
