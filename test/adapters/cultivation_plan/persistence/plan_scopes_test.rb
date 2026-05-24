# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    module Persistence
      class PlanScopesTest < ActiveSupport::TestCase
        test "find_record! public resolves plan visible under public scope" do
          farm = create(:farm, :reference)
          plan = create(:cultivation_plan, :public_plan, :completed, farm: farm)
          auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :public)

          found = PlanScopes.find_record!(auth, plan.id)

          assert_equal plan.id, found.id
          assert_predicate found, :plan_type_public?
        end

        test "find_record! public raises RecordNotFound when id absent" do
          auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :public)

          assert_raises(ActiveRecord::RecordNotFound) do
            PlanScopes.find_record!(auth, 9_999_999_999)
          end
        end

        test "find_record! public does not expose private plans" do
          user = create(:user)
          farm = create(:farm, user: user)
          plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private", status: "completed")
          auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :public)

          assert_raises(ActiveRecord::RecordNotFound) do
            PlanScopes.find_record!(auth, plan.id)
          end
        end

        test "find_record! private loads plan owned by authenticated user" do
          user = create(:user)
          farm = create(:farm, user: user)
          plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private", status: "completed")
          auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: user.id)

          found = PlanScopes.find_record!(auth, plan.id)

          assert_equal plan.id, found.id
        end

        test "find_record! private raises RecordNotFound for another users plan" do
          owner = create(:user)
          other = create(:user)
          farm = create(:farm, user: owner)
          plan = create(:cultivation_plan, farm: farm, user: owner, plan_type: "private", status: "completed")
          auth = Domain::CultivationPlan::Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: other.id)

          assert_raises(ActiveRecord::RecordNotFound) do
            PlanScopes.find_record!(auth, plan.id)
          end
        end
      end
    end
  end
end
