# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Policies
      class CultivationPlanOptimizationCompletePolicyTest < DomainLibTestCase
        test "should_mark_plan_completed when optimizing and all field cultivations completed" do
          assert Policies::CultivationPlanOptimizationCompletePolicy.should_mark_plan_completed?(
            plan_status: "optimizing",
            field_cultivation_statuses: %w[completed completed]
          )
        end

        test "should not mark when not optimizing" do
          refute Policies::CultivationPlanOptimizationCompletePolicy.should_mark_plan_completed?(
            plan_status: "completed",
            field_cultivation_statuses: %w[completed]
          )
        end

        test "should not mark when field cultivations empty" do
          refute Policies::CultivationPlanOptimizationCompletePolicy.should_mark_plan_completed?(
            plan_status: "optimizing",
            field_cultivation_statuses: []
          )
        end
      end
    end
  end
end
