# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Policies
      class PrivateCultivationPlanAccessPolicyTest < DomainLibTestCase
        def private_plan_entity(user_id: 1)
          Entities::CultivationPlanEntity.new(
            id: 10,
            farm_id: 1,
            user_id: user_id,
            total_area: 100,
            plan_type: "private"
          )
        end

        test "access_denied? is false when user owns a private plan" do
          refute PrivateCultivationPlanAccessPolicy.access_denied?(
            plan: private_plan_entity(user_id: 5),
            user_id: 5
          )
        end

        test "access_denied? is true when user_id does not match" do
          assert PrivateCultivationPlanAccessPolicy.access_denied?(
            plan: private_plan_entity(user_id: 5),
            user_id: 99
          )
        end

        test "access_denied? is true when plan is not private" do
          plan = Entities::CultivationPlanEntity.new(
            id: 10,
            farm_id: 1,
            user_id: 5,
            total_area: 100,
            plan_type: "public"
          )

          assert PrivateCultivationPlanAccessPolicy.access_denied?(plan: plan, user_id: 5)
        end
      end
    end
  end
end
