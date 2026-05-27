# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    module Persistence
      class CultivationPlanRestPlanPreloadTest < ActiveSupport::TestCase
        test "find_by_plan_id_public resolves plan visible under public scope" do
          farm = create(:farm, :reference)
          plan = create(:cultivation_plan, :public_plan, :completed, farm: farm)

          found = CultivationPlanRestPlanPreload.find_by_plan_id_public(plan_id: plan.id)

          assert_equal plan.id, found.id
          assert_predicate found, :plan_type_public?
        end

        test "find_by_plan_id_public raises RecordNotFound when id absent" do
          assert_raises(ActiveRecord::RecordNotFound) do
            CultivationPlanRestPlanPreload.find_by_plan_id_public(plan_id: 9_999_999_999)
          end
        end

        test "find_by_plan_id_public does not expose private plans" do
          user = create(:user)
          farm = create(:farm, user: user)
          plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private", status: "completed")

          assert_raises(ActiveRecord::RecordNotFound) do
            CultivationPlanRestPlanPreload.find_by_plan_id_public(plan_id: plan.id)
          end
        end

        test "find_by_plan_id_and_user_id loads plan owned by authenticated user" do
          user = create(:user)
          farm = create(:farm, user: user)
          plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private", status: "completed")

          found = CultivationPlanRestPlanPreload.find_by_plan_id_and_user_id(
            plan_id: plan.id,
            user_id: user.id
          )

          assert_equal plan.id, found.id
        end

        test "find_by_plan_id_and_user_id raises RecordNotFound for another users plan" do
          owner = create(:user)
          other = create(:user)
          farm = create(:farm, user: owner)
          plan = create(:cultivation_plan, farm: farm, user: owner, plan_type: "private", status: "completed")

          assert_raises(ActiveRecord::RecordNotFound) do
            CultivationPlanRestPlanPreload.find_by_plan_id_and_user_id(
              plan_id: plan.id,
              user_id: other.id
            )
          end
        end
      end
    end
  end
end
