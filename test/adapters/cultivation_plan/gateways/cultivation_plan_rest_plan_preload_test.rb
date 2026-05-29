# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    module Gateways
      class CultivationPlanRestPlanPreloadTest < ActiveSupport::TestCase
        test "find_by_plan_id resolves public plan by id" do
          farm = create(:farm, :reference)
          plan = create(:cultivation_plan, :public_plan, :completed, farm: farm)

          found = CultivationPlanRestPlanPreload.find_by_plan_id(plan_id: plan.id)

          assert_equal plan.id, found.id
          assert_predicate found, :plan_type_public?
        end

        test "find_by_plan_id resolves private plan by id" do
          user = create(:user)
          farm = create(:farm, user: user)
          plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private", status: "completed")

          found = CultivationPlanRestPlanPreload.find_by_plan_id(plan_id: plan.id)

          assert_equal plan.id, found.id
          assert_predicate found, :plan_type_private?
        end

        test "find_by_plan_id raises RecordNotFound when id absent" do
          assert_raises(ActiveRecord::RecordNotFound) do
            CultivationPlanRestPlanPreload.find_by_plan_id(plan_id: 9_999_999_999)
          end
        end
      end
    end
  end
end
