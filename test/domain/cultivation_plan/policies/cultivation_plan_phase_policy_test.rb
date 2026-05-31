# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Policies
      class CultivationPlanPhasePolicyTest < DomainLibTestCase
        test "build start_optimizing sets initializing phase with broadcast" do
          built = CultivationPlanPhasePolicy.build(phase_name: :start_optimizing)

          assert_equal(
            {
              status: "optimizing",
              optimization_phase: "initializing"
            },
            built[:attrs]
          )
          assert_equal "models.cultivation_plan.phases.initializing", built[:message_key]
          assert built[:broadcast]
        end

        test "build phase phase_attrs with message key and broadcast" do
          built = CultivationPlanPhasePolicy.build(phase_name: :phase_fetching_weather)

          assert_equal({ optimization_phase: "fetching_weather" }, built[:attrs])
          assert_equal "models.cultivation_plan.phases.fetching_weather", built[:message_key]
          assert built[:broadcast]
        end

        test "build phase_failed uses failure subphase message key" do
          built = CultivationPlanPhasePolicy.build(
            phase_name: :phase_failed,
            failure_subphase: "task_schedule_generation"
          )

          assert_equal(
            { optimization_phase: "failed", status: "failed" },
            built[:attrs]
          )
          assert_equal(
            "models.cultivation_plan.phase_failed.task_schedule_generation",
            built[:message_key]
          )
          assert built[:broadcast]
        end

        test "build phase_failed defaults message key when subphase unknown" do
          built = CultivationPlanPhasePolicy.build(phase_name: :phase_failed)

          assert_equal "models.cultivation_plan.phase_failed.default", built[:message_key]
        end

        test "build accepts string phase name" do
          built = CultivationPlanPhasePolicy.build(phase_name: "phase_completed")

          assert_equal({ optimization_phase: "completed" }, built[:attrs])
          assert_equal "models.cultivation_plan.phases.completed", built[:message_key]
        end

        test "build raises for unknown phase" do
          assert_raises(ArgumentError, match: /Unknown cultivation plan phase/) do
            CultivationPlanPhasePolicy.build(phase_name: :not_a_phase)
          end
        end
      end
    end
  end
end
